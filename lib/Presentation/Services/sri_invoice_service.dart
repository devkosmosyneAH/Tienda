import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:sri_xml_validator/sri_xml_validator.dart';
import 'package:xml/xml.dart';

import '../Model/sri_store_config_model.dart';
import 'audit_service.dart';
import 'database_service.dart';
import 'sri_config_service.dart';

class SriEmitResult {
  const SriEmitResult({
    required this.status,
    this.message = '',
    this.electronicInvoiceId,
    this.accessKey,
    this.authorizationNumber,
    this.authorizationDate,
  });

  final String status;
  final String message;
  final int? electronicInvoiceId;
  final String? accessKey;
  final String? authorizationNumber;
  final DateTime? authorizationDate;

  bool get isSuccess => status == 'AUTORIZADO' || status == 'RECIBIDO';
}

class _InvoiceLine {
  const _InvoiceLine({
    required this.code,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.gross,
    required this.discount,
    required this.taxBase,
    required this.taxRate,
    required this.taxCode,
  });

  final String code;
  final String description;
  final double quantity;
  final double unitPrice;
  final double gross;
  final double discount;
  final double taxBase;
  final double taxRate;
  final String taxCode;

  double get tax => ((gross - taxBase) * 100).roundToDouble() / 100;
}

class SriInvoiceService {
  static bool get isGlobalEnabled => SriConfigService.globalEnabled;

  static const _invoiceXsd = 'factura_V1.1.0.xsd';
  static const _sriPollAttempts = 5;
  static const _sriPollInterval = Duration(seconds: 2);
  static final Random _secureRandom = Random.secure();

  static Future<SriEmitResult> emitForSale({
    required int saleId,
    required int storeId,
  }) async {
    if (!isGlobalEnabled) {
      return const SriEmitResult(
        status: 'SKIPPED',
        message: 'SRI global deshabilitado.',
      );
    }

    final config = await SriConfigService.getConfig(storeId);
    final validationError = SriConfigService.validateConfig(config);
    if (config == null || validationError.isNotEmpty) {
      return SriEmitResult(
        status: 'ERROR',
        message: validationError.isEmpty
            ? 'No hay configuración SRI para este local.'
            : validationError,
      );
    }
    if (!config.autoEmitOnCheckout) {
      return const SriEmitResult(
        status: 'SKIPPED',
        message: 'La emisión automática está desactivada para este local.',
      );
    }

    final result = await _emitForSale(
      saleId: saleId,
      storeId: storeId,
      config: config,
    );
    if (result.status == 'ERROR') {
      await AuditService.log(
        action: 'SRI_EMIT_ERROR',
        module: 'SRI',
        page: 'POS',
        entity: 'electronic_invoices',
        entityId: result.electronicInvoiceId ?? saleId,
        description: 'Fallo al emitir comprobante SRI',
        error: result.message,
        controller: 'SriInvoiceService',
      );
    }
    return result;
  }

  static Future<SriEmitResult> retry({
    required int electronicInvoiceId,
    required int storeId,
  }) async {
    if (!isGlobalEnabled) {
      return const SriEmitResult(
        status: 'SKIPPED',
        message: 'SRI global deshabilitado.',
      );
    }

    final config = await SriConfigService.getConfig(storeId);
    final validationError = SriConfigService.validateConfig(config);
    if (config == null || validationError.isNotEmpty) {
      return SriEmitResult(
        status: 'ERROR',
        message: validationError.isEmpty
            ? 'El local no tiene una configuración SRI válida.'
            : validationError,
      );
    }

    final db = await DatabaseService.database;
    final rows = await db.rawQuery(
      'SELECT * FROM electronic_invoices WHERE id = ? AND store_id = ? LIMIT 1',
      [electronicInvoiceId, storeId],
    );
    if (rows.isEmpty) {
      return const SriEmitResult(
        status: 'ERROR',
        message: 'Comprobante no encontrado en este local.',
      );
    }

    final invoice = rows.first;
    final currentStatus = (invoice['estado'] as String?) ?? 'PENDIENTE';
    final accessKey = (invoice['clave_acceso'] as String?) ?? '';
    if (currentStatus == 'AUTORIZADO') {
      return SriEmitResult(
        status: currentStatus,
        message: 'El comprobante ya está autorizado.',
        electronicInvoiceId: electronicInvoiceId,
        accessKey: accessKey,
        authorizationNumber: invoice['authorization_number'] as String?,
        authorizationDate: DateTime.tryParse(
          (invoice['authorization_date'] as String?) ?? '',
        ),
      );
    }

    if (currentStatus == 'RECIBIDO' && accessKey.isNotEmpty) {
      final xml = (invoice['xml'] as String?) ?? '';
      try {
        return await _checkAuthorization(
          accessKey: accessKey,
          config: config,
          invoiceId: electronicInvoiceId,
          unsignedXml: xml,
        );
      } catch (error) {
        final message =
            'El comprobante fue recibido, pero no se pudo consultar su autorización: '
            '${_safeErrorMessage(error, config)}';
        await _updateInvoice(
          invoiceId: electronicInvoiceId,
          accessKey: accessKey,
          state: 'RECIBIDO',
          xml: xml,
          errorMessage: message,
        );
        return SriEmitResult(
          status: 'RECIBIDO',
          message: message,
          electronicInvoiceId: electronicInvoiceId,
          accessKey: accessKey,
        );
      }
    }

    return _emitForSale(
      saleId: (invoice['sale_id'] as num).toInt(),
      storeId: storeId,
      config: config,
      existingInvoiceId: electronicInvoiceId,
    );
  }

  static Future<SriEmitResult> _emitForSale({
    required int saleId,
    required int storeId,
    required SriStoreConfig config,
    int? existingInvoiceId,
  }) async {
    int? invoiceId = existingInvoiceId;
    String? accessKey;
    String? unsignedXml;

    try {
      final db = await DatabaseService.database;
      final saleRows = await db.rawQuery(
        '''
        SELECT sa.id, sa.store_id, sa.client_id, sa.date, sa.total,
               c.name AS customer_name, c.cedula AS customer_identification,
               c.identification_type AS customer_identification_type,
               c.address AS customer_address
        FROM sales sa
        LEFT JOIN clients c ON c.id = sa.client_id
        WHERE sa.id = ? AND sa.store_id = ?
        LIMIT 1
        ''',
        [saleId, storeId],
      );
      if (saleRows.isEmpty) {
        throw StateError('La venta no existe en el local seleccionado.');
      }
      final sale = Map<String, dynamic>.from(saleRows.first);
      final itemRows = await db.rawQuery(
        '''
        SELECT si.product_id, si.quantity, si.price,
               p.name AS product_name, p.iva_rate, p.sku, p.aux_code
        FROM sale_items si
        JOIN products p ON p.id = si.product_id
        WHERE si.sale_id = ?
        ORDER BY si.id
        ''',
        [saleId],
      );
      if (itemRows.isEmpty) {
        throw StateError('La venta no contiene productos para facturar.');
      }

      final customer = sale['client_id'] == null
          ? null
          : <String, dynamic>{
              'name': sale['customer_name'],
              'identification_number': sale['customer_identification'],
              'identification_type': sale['customer_identification_type'],
              'address': sale['customer_address'],
            };
      final customerIdentification =
          (customer?['identification_number'] as String?)?.trim() ?? '';
      final consumerFinal =
          sale['client_id'] == null || customerIdentification.isEmpty;
      final customerError = validateCustomerData(
        ruc: customer?['identification_type'] == 'ruc'
            ? customerIdentification
            : null,
        cedula: customer?['identification_type'] == 'cedula'
            ? customerIdentification
            : null,
        identificationType: customer?['identification_type'] as String?,
        consumerFinal: consumerFinal,
      );
      if (customerError.isNotEmpty) {
        throw StateError(customerError);
      }

      final invoiceRows = await db.rawQuery(
        'SELECT id, clave_acceso, estado FROM electronic_invoices WHERE store_id = ? AND sale_id = ? ORDER BY id DESC LIMIT 1',
        [storeId, saleId],
      );
      if (invoiceRows.isNotEmpty && invoiceId == null) {
        final previous = invoiceRows.first;
        final previousStatus = (previous['estado'] as String?) ?? '';
        if (previousStatus == 'AUTORIZADO') {
          return SriEmitResult(
            status: 'AUTORIZADO',
            message: 'La venta ya tiene una factura autorizada.',
            electronicInvoiceId: (previous['id'] as num).toInt(),
            accessKey: previous['clave_acceso'] as String?,
          );
        }
        if (previousStatus == 'RECIBIDO' || previousStatus == 'PENDIENTE') {
          return SriEmitResult(
            status: previousStatus,
            message: 'La factura ya está en proceso de autorización.',
            electronicInvoiceId: (previous['id'] as num).toInt(),
            accessKey: previous['clave_acceso'] as String?,
          );
        }
        invoiceId = (previous['id'] as num).toInt();
        accessKey = previous['clave_acceso'] as String?;
      }

      if (invoiceId == null) {
        invoiceId = await _persistEmissionRecord(
          storeId: storeId,
          saleId: saleId,
          clientId: (sale['client_id'] as num?)?.toInt(),
          config: config,
        );
      } else if (accessKey == null || accessKey.isEmpty) {
        final existingRows = await db.rawQuery(
          'SELECT clave_acceso FROM electronic_invoices WHERE id = ? AND store_id = ? LIMIT 1',
          [invoiceId, storeId],
        );
        accessKey = existingRows.isEmpty
            ? null
            : existingRows.first['clave_acceso'] as String?;
      }

      final date = DateTime.tryParse(sale['date'] as String? ?? '');
      if (date == null) {
        throw StateError('La fecha de venta no es válida para el SRI.');
      }
      final sequence = accessKey != null && accessKey.length == 49
          ? int.parse(accessKey.substring(30, 39))
          : await nextSequence(
              storeId,
              codDoc: config.facturaTipo,
              estab: config.codigoEstablecimiento,
              ptoEmi: config.puntoEmision,
            );
      accessKey ??= generateAccessKey(
        ruc: config.ruc,
        documentCode: config.facturaTipo,
        ambiente: config.ambiente,
        estab: config.codigoEstablecimiento,
        ptoEmi: config.puntoEmision,
        sequence: sequence,
        date: date,
        tipoEmision: _emissionTypeCode(config.tipoEmision),
      );

      final payments = await _loadPayments(db, saleId);
      sale['payments'] = payments;
      final normalizedItems = itemRows
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      unsignedXml = buildInvoiceXml(
        config: config,
        sale: sale,
        customer: customer,
        items: normalizedItems,
        accessKey: accessKey,
        sequence: sequence,
      );
      await _updateInvoice(
        invoiceId: invoiceId,
        accessKey: accessKey,
        state: 'PENDIENTE',
        xml: unsignedXml,
        errorMessage: null,
      );

      if (!Platform.isAndroid && !Platform.isWindows) {
        throw UnsupportedError(
          'La firma XAdES-BES configurada está disponible únicamente en Android y Windows.',
        );
      }
      final certificate = await File(config.pathP12).readAsBytes();
      final transport = http.Client();
      try {
        final client = SriClient(
          ambiente: config.ambiente == 2
              ? AmbienteSri.produccion
              : AmbienteSri.pruebas,
          httpClient: transport,
        );
        await client.inicializarEsquemas();
        final emission = await client.emitirComprobanteCompleto(
          p12Bytes: certificate,
          p12Password: config.p12Password,
          xmlSinFirmar: unsignedXml,
          claveAcceso: accessKey,
          xsdFileName: _invoiceXsd,
        );
        var finalEmission = emission;
        if (emission.estado == EstadoAutorizacion.enProceso) {
          try {
            finalEmission = await _pollAuthorization(
              accessKey: accessKey,
              config: config,
            );
          } catch (error) {
            final message =
                'Comprobante recibido; falló la consulta de autorización: '
                '${_safeErrorMessage(error, config)}';
            await _updateInvoice(
              invoiceId: invoiceId,
              accessKey: accessKey,
              state: 'RECIBIDO',
              xml: unsignedXml,
              errorMessage: message,
            );
            return SriEmitResult(
              status: 'RECIBIDO',
              message: message,
              electronicInvoiceId: invoiceId,
              accessKey: accessKey,
            );
          }
        }

        return await _saveEmissionResult(
          invoiceId: invoiceId,
          accessKey: accessKey,
          unsignedXml: unsignedXml,
          result: finalEmission,
        );
      } finally {
        transport.close();
      }
    } catch (error) {
      final message = _safeErrorMessage(error, config);
      if (invoiceId != null) {
        await _updateInvoice(
          invoiceId: invoiceId,
          accessKey: accessKey ?? '',
          state: 'ERROR',
          xml: unsignedXml,
          errorMessage: message,
        );
      }
      return SriEmitResult(
        status: 'ERROR',
        message: message,
        electronicInvoiceId: invoiceId,
        accessKey: accessKey,
      );
    }
  }

  static Future<List<Map<String, dynamic>>> _loadPayments(
    dynamic db,
    int saleId,
  ) async {
    final creditRows = await db.rawQuery(
      'SELECT id FROM credit_sales WHERE sale_id = ? LIMIT 1',
      [saleId],
    );
    if (creditRows.isNotEmpty) {
      return [
        {'forma_pago': '20', 'total': 0, 'credito': true},
      ];
    }
    final rows = await db.rawQuery(
      '''
      SELECT pm.name, SUM(sp.amount) AS total
      FROM sale_payments sp
      JOIN payment_methods pm ON pm.id = sp.method_id
      WHERE sp.sale_id = ?
      GROUP BY pm.name
      ''',
      [saleId],
    );
    return rows
        .map(
          (row) => <String, dynamic>{
            'forma_pago': _paymentCode(row['name'] as String? ?? ''),
            'total': (row['total'] as num?)?.toDouble() ?? 0,
            'credito': false,
          },
        )
        .toList();
  }

  static String _paymentCode(String method) {
    final normalized = method.trim().toLowerCase();
    if (normalized.contains('efectivo')) return '01';
    if (normalized.contains('tarjeta')) return '19';
    return '20';
  }

  static Future<SriEmitResult> _checkAuthorization({
    required String accessKey,
    required SriStoreConfig config,
    required int invoiceId,
    required String unsignedXml,
  }) async {
    final client = http.Client();
    try {
      final ws = SriWsRepositoryImpl(
        client,
        ambiente: config.ambiente == 2
            ? AmbienteSri.produccion
            : AmbienteSri.pruebas,
      );
      final result = await _pollAuthorization(
        ws: ws,
        accessKey: accessKey,
        config: config,
      );
      return _saveEmissionResult(
        invoiceId: invoiceId,
        accessKey: accessKey,
        unsignedXml: unsignedXml,
        result: result,
      );
    } finally {
      client.close();
    }
  }

  static Future<ResultadoEmision> _pollAuthorization({
    SriWsRepositoryImpl? ws,
    required String accessKey,
    required SriStoreConfig config,
  }) async {
    final httpClient = ws == null ? http.Client() : null;
    try {
      final repository =
          ws ??
          SriWsRepositoryImpl(
            httpClient!,
            ambiente: config.ambiente == 2
                ? AmbienteSri.produccion
                : AmbienteSri.pruebas,
          );
      var result = await repository.consultarAutorizacion(accessKey);
      for (
        var attempt = 0;
        result.estado == EstadoAutorizacion.enProceso &&
            attempt < _sriPollAttempts;
        attempt++
      ) {
        await Future<void>.delayed(_sriPollInterval);
        result = await repository.consultarAutorizacion(accessKey);
      }
      return result;
    } finally {
      httpClient?.close();
    }
  }

  static Future<SriEmitResult> _saveEmissionResult({
    required int invoiceId,
    required String accessKey,
    required String unsignedXml,
    required ResultadoEmision result,
  }) async {
    final status = switch (result.estado) {
      EstadoAutorizacion.autorizado => 'AUTORIZADO',
      EstadoAutorizacion.noAutorizado => 'NO AUTORIZADO',
      EstadoAutorizacion.rechazado => 'DEVUELTA',
      EstadoAutorizacion.enProceso => 'RECIBIDO',
    };
    final messages = result.mensajes
        .map(
          (message) => [
            if (message.identificador.isNotEmpty) '[${message.identificador}]',
            message.mensaje,
            if ((message.informacionAdicional ?? '').isNotEmpty)
              message.informacionAdicional!,
          ].where((part) => part.isNotEmpty).join(' '),
        )
        .where((message) => message.isNotEmpty)
        .join('\n');
    final successMessage = switch (status) {
      'AUTORIZADO' => 'Factura autorizada por el SRI.',
      'RECIBIDO' => 'Comprobante recibido; autorización aún en proceso.',
      'DEVUELTA' => 'El SRI devolvió el comprobante.',
      _ => 'El SRI no autorizó el comprobante.',
    };
    final message = messages.isEmpty ? successMessage : messages;
    await _updateInvoice(
      invoiceId: invoiceId,
      accessKey: accessKey,
      state: status,
      xml: result.xmlAutorizado ?? unsignedXml,
      errorMessage: status == 'AUTORIZADO' || status == 'RECIBIDO'
          ? null
          : message,
      authorizationNumber: result.numeroAutorizacion,
      authorizationDate: result.fechaAutorizacion,
    );
    return SriEmitResult(
      status: status,
      message: message,
      electronicInvoiceId: invoiceId,
      accessKey: accessKey,
      authorizationNumber: result.numeroAutorizacion,
      authorizationDate: result.fechaAutorizacion,
    );
  }

  static String validateCustomerData({
    String? ruc,
    String? cedula,
    String? identificationType,
    bool consumerFinal = false,
  }) {
    if (consumerFinal) return '';
    final normalizedRuc = (ruc ?? '').trim();
    final normalizedCedula = (cedula ?? '').trim();
    final type = (identificationType ?? '').trim().toLowerCase();

    if (type == 'ruc' || normalizedRuc.isNotEmpty) {
      return RegExp(r'^\d{13}$').hasMatch(normalizedRuc)
          ? ''
          : 'El RUC del comprador debe tener 13 dígitos.';
    }
    if (type == 'cedula' || normalizedCedula.isNotEmpty) {
      return RegExp(r'^\d{10}$').hasMatch(normalizedCedula)
          ? ''
          : 'La cédula del comprador debe tener 10 dígitos.';
    }
    return 'Debe indicarse RUC (13 dígitos), cédula válida o consumidor final.';
  }

  static Map<String, dynamic> buildInvoicePayload({
    required int storeId,
    required int saleId,
    required double total,
    required SriStoreConfig config,
    required Map<String, dynamic> sale,
    required Map<String, dynamic>? customer,
    required List<Map<String, dynamic>> items,
  }) {
    final customerName = (customer?['name'] as String?) ?? 'Consumidor final';
    final customerId =
        (customer?['cedula'] as String?) ??
        (customer?['identification_number'] as String?) ??
        '9999999999999';

    return {
      'store_id': storeId,
      'sale_id': saleId,
      'document_code': config.facturaTipo,
      'ambiente': config.ambiente,
      'ruc': config.ruc,
      'establecimiento': config.codigoEstablecimiento,
      'punto_emision': config.puntoEmision,
      'cliente_nombre': customerName,
      'cliente_id': customerId,
      'total': total,
      'fecha': sale['date'] ?? DateTime.now().toIso8601String(),
      'items': items,
    };
  }

  static String buildInvoiceXml({
    required SriStoreConfig config,
    required Map<String, dynamic> sale,
    required Map<String, dynamic>? customer,
    required List<Map<String, dynamic>> items,
    required String accessKey,
    required int sequence,
  }) {
    if (config.facturaTipo != '01') {
      throw ArgumentError('Solo se admite factura electrónica tipo 01.');
    }
    if (accessKey.length != 49 || !RegExp(r'^\d{49}$').hasMatch(accessKey)) {
      throw ArgumentError('La clave de acceso debe contener 49 dígitos.');
    }
    if (int.parse(accessKey[48]) !=
        calculateModulo11(accessKey.substring(0, 48))) {
      throw ArgumentError(
        'El dígito verificador de la clave de acceso no es válido.',
      );
    }
    final issueDate = DateTime.tryParse(sale['date'] as String? ?? '');
    if (issueDate == null) {
      throw ArgumentError('La fecha de emisión de la venta no es válida.');
    }

    final customerData = _customerInfo(customer);
    final customerError = validateCustomerData(
      ruc: customerData.identificationType == '04'
          ? customerData.identification
          : null,
      cedula: customerData.identificationType == '05'
          ? customerData.identification
          : null,
      identificationType: customerData.identificationType == '04'
          ? 'ruc'
          : customerData.identificationType == '05'
          ? 'cedula'
          : null,
      consumerFinal: customerData.identificationType == '07',
    );
    if (customerError.isNotEmpty) throw ArgumentError(customerError);

    final invoiceLines = items.map(_buildInvoiceLine).toList();
    final grossTotal = _money(
      invoiceLines.fold<double>(0, (total, line) => total + line.gross),
    );
    final saleTotal = _money(_asDouble(sale['total']));
    if ((grossTotal - saleTotal).abs() > 0.01) {
      throw StateError(
        'Los importes de los productos no coinciden con el total guardado de la venta.',
      );
    }
    final basesByRate = <String, double>{};
    final taxesByRate = <String, double>{};
    final ratesByCode = <String, double>{};
    for (final line in invoiceLines) {
      basesByRate.update(
        line.taxCode,
        (base) => _money(base + line.taxBase),
        ifAbsent: () => line.taxBase,
      );
      taxesByRate.update(
        line.taxCode,
        (tax) => _money(tax + line.tax),
        ifAbsent: () => line.tax,
      );
      ratesByCode[line.taxCode] = line.taxRate;
    }
    final totalWithoutTaxes = _money(
      invoiceLines.fold<double>(0, (total, line) => total + line.taxBase),
    );
    final totalDiscount = _money(
      invoiceLines.fold<double>(0, (sum, line) => sum + line.discount),
    );
    final paymentLines = _normalizePayments(
      sale['payments'] as List<Map<String, dynamic>>?,
      saleTotal,
    );
    final typeEmission = _emissionTypeCode(config.tipoEmision);

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'factura',
      attributes: {'id': 'comprobante', 'version': '1.1.0'},
      nest: () {
        builder.element(
          'infoTributaria',
          nest: () {
            _xmlText(builder, 'ambiente', config.ambiente.toString());
            _xmlText(builder, 'tipoEmision', typeEmission);
            _xmlText(builder, 'razonSocial', config.razonSocial);
            if (config.nombreComercial.trim().isNotEmpty) {
              _xmlText(builder, 'nombreComercial', config.nombreComercial);
            }
            _xmlText(builder, 'ruc', config.ruc);
            _xmlText(builder, 'claveAcceso', accessKey);
            _xmlText(builder, 'codDoc', config.facturaTipo);
            _xmlText(builder, 'estab', config.codigoEstablecimiento);
            _xmlText(builder, 'ptoEmi', config.puntoEmision);
            _xmlText(
              builder,
              'secuencial',
              sequence.toString().padLeft(9, '0'),
            );
            _xmlText(builder, 'dirMatriz', config.direccionMatriz);
          },
        );
        builder.element(
          'infoFactura',
          nest: () {
            _xmlText(
              builder,
              'fechaEmision',
              '${issueDate.day.toString().padLeft(2, '0')}/${issueDate.month.toString().padLeft(2, '0')}/${issueDate.year}',
            );
            _xmlText(builder, 'dirEstablecimiento', config.direccionMatriz);
            _xmlText(
              builder,
              'tipoIdentificacionComprador',
              customerData.identificationType,
            );
            _xmlText(builder, 'razonSocialComprador', customerData.name);
            _xmlText(
              builder,
              'identificacionComprador',
              customerData.identification,
            );
            if (customerData.address.isNotEmpty) {
              _xmlText(builder, 'direccionComprador', customerData.address);
            }
            _xmlText(
              builder,
              'totalSinImpuestos',
              _formatMoney(totalWithoutTaxes),
            );
            _xmlText(builder, 'totalDescuento', _formatMoney(totalDiscount));
            builder.element(
              'totalConImpuestos',
              nest: () {
                for (final code in basesByRate.keys.toList()..sort()) {
                  builder.element(
                    'totalImpuesto',
                    nest: () {
                      _xmlText(builder, 'codigo', '2');
                      _xmlText(builder, 'codigoPorcentaje', code);
                      _xmlText(
                        builder,
                        'baseImponible',
                        _formatMoney(basesByRate[code]!),
                      );
                      _xmlText(
                        builder,
                        'tarifa',
                        _formatMoney(ratesByCode[code]!),
                      );
                      _xmlText(
                        builder,
                        'valor',
                        _formatMoney(taxesByRate[code]!),
                      );
                    },
                  );
                }
              },
            );
            _xmlText(builder, 'propina', '0.00');
            _xmlText(builder, 'importeTotal', _formatMoney(saleTotal));
            _xmlText(builder, 'moneda', 'DOLAR');
            builder.element(
              'pagos',
              nest: () {
                for (final payment in paymentLines) {
                  builder.element(
                    'pago',
                    nest: () {
                      _xmlText(
                        builder,
                        'formaPago',
                        payment['forma_pago']! as String,
                      );
                      _xmlText(
                        builder,
                        'total',
                        _formatMoney(payment['total']! as double),
                      );
                    },
                  );
                }
              },
            );
          },
        );
        builder.element(
          'detalles',
          nest: () {
            for (var index = 0; index < invoiceLines.length; index++) {
              final line = invoiceLines[index];
              final item = items[index];
              builder.element(
                'detalle',
                nest: () {
                  _xmlText(builder, 'codigoPrincipal', line.code);
                  final auxCode = (item['aux_code'] as String?)?.trim() ?? '';
                  if (auxCode.isNotEmpty) {
                    _xmlText(builder, 'codigoAuxiliar', auxCode);
                  }
                  _xmlText(builder, 'descripcion', line.description);
                  _xmlText(builder, 'cantidad', _formatQuantity(line.quantity));
                  _xmlText(
                    builder,
                    'precioUnitario',
                    _formatMoney(line.unitPrice),
                  );
                  _xmlText(builder, 'descuento', _formatMoney(line.discount));
                  _xmlText(
                    builder,
                    'precioTotalSinImpuesto',
                    _formatMoney(line.taxBase),
                  );
                  builder.element(
                    'impuestos',
                    nest: () {
                      builder.element(
                        'impuesto',
                        nest: () {
                          _xmlText(builder, 'codigo', '2');
                          _xmlText(builder, 'codigoPorcentaje', line.taxCode);
                          _xmlText(
                            builder,
                            'tarifa',
                            _formatMoney(line.taxRate),
                          );
                          _xmlText(
                            builder,
                            'baseImponible',
                            _formatMoney(line.taxBase),
                          );
                          _xmlText(builder, 'valor', _formatMoney(line.tax));
                        },
                      );
                    },
                  );
                },
              );
            }
          },
        );
      },
    );
    return builder.buildDocument().toXmlString(pretty: false);
  }

  static _InvoiceLine _buildInvoiceLine(Map<String, dynamic> item) {
    final quantity = _asDouble(item['quantity']);
    final unitPrice = _asDouble(item['price'] ?? item['unit_price']);
    final discount = _asDouble(item['discount']);
    final taxRate = _asDouble(item['iva_rate']);
    if (quantity <= 0 || unitPrice < 0 || discount < 0 || taxRate < 0) {
      throw ArgumentError(
        'Cantidad, precio o impuesto inválido en un detalle.',
      );
    }
    final taxCode = _ivaCode(taxRate);
    // POS sale totals are quantity multiplied by the stored retail price.
    // Treat that amount as tax-inclusive so the invoice total stays identical.
    final lineDiscount = _money(discount * quantity);
    final gross = _money(unitPrice * quantity - lineDiscount);
    final base = taxRate == 0 ? gross : _money(gross / (1 + taxRate / 100));
    final name =
        (item['product_name'] as String?) ??
        (item['name'] as String?) ??
        'Producto';
    final code = (item['sku'] as String?)?.trim().isNotEmpty == true
        ? (item['sku'] as String).trim()
        : (item['product_id']?.toString() ?? '1');
    return _InvoiceLine(
      code: code,
      description: name,
      quantity: quantity,
      unitPrice: unitPrice,
      gross: gross,
      discount: lineDiscount,
      taxBase: base,
      taxRate: taxRate,
      taxCode: taxCode,
    );
  }

  static String _ivaCode(double rate) {
    final normalized = rate.toStringAsFixed(2);
    return switch (normalized) {
      '0.00' => '0',
      '12.00' => '2',
      '14.00' => '3',
      '15.00' => '4',
      '5.00' => '5',
      '8.00' => '6',
      '13.00' => '10',
      _ => throw ArgumentError(
        'La tarifa IVA $normalized% no tiene un código SRI configurado.',
      ),
    };
  }

  static List<Map<String, Object>> _normalizePayments(
    List<Map<String, dynamic>>? rawPayments,
    double total,
  ) {
    if (rawPayments == null || rawPayments.isEmpty) {
      return [
        {'forma_pago': '01', 'total': total},
      ];
    }
    if (rawPayments.any((payment) => payment['credito'] == true)) {
      return [
        {'forma_pago': '20', 'total': total},
      ];
    }
    final payments = rawPayments
        .map(
          (payment) => <String, Object>{
            'forma_pago': (payment['forma_pago'] as String?) ?? '20',
            'total': _money(_asDouble(payment['total'])),
          },
        )
        .where((payment) => (payment['total']! as double) > 0)
        .toList();
    final paid = _money(
      payments.fold<double>(
        0,
        (sum, payment) => sum + (payment['total']! as double),
      ),
    );
    if ((paid - total).abs() > 0.01) {
      throw StateError(
        'Los pagos registrados no coinciden con el total de la factura.',
      );
    }
    return payments;
  }

  static ({
    String name,
    String identification,
    String identificationType,
    String address,
  })
  _customerInfo(Map<String, dynamic>? customer) {
    final name = (customer?['name'] as String?)?.trim();
    final rawIdentification =
        (customer?['identification_number'] as String?)?.trim() ??
        (customer?['cedula'] as String?)?.trim() ??
        '';
    final rawType =
        (customer?['identification_type'] as String?)?.trim().toLowerCase() ??
        '';
    if (customer == null || rawIdentification.isEmpty) {
      return (
        name: 'Consumidor final',
        identification: '9999999999999',
        identificationType: '07',
        address: '',
      );
    }
    final idType = switch (rawType) {
      'ruc' || '04' => '04',
      'cedula' || 'cédula' || '05' => '05',
      'pasaporte' || '06' => '06',
      'consumidor final' || '07' => '07',
      _ when rawIdentification.length == 13 => '04',
      _ when rawIdentification.length == 10 => '05',
      _ => throw ArgumentError(
        'El tipo de identificación del comprador no es válido.',
      ),
    };
    return (
      name: name?.isNotEmpty == true ? name! : 'Consumidor final',
      identification: rawIdentification,
      identificationType: idType,
      address: (customer['address'] as String?)?.trim() ?? '',
    );
  }

  static Future<int> nextSequence(
    int storeId, {
    String codDoc = '01',
    String estab = '001',
    String ptoEmi = '001',
  }) async {
    final db = await DatabaseService.database;
    return db.transaction((txn) async {
      final rows = await txn.rawQuery(
        '''
        SELECT current_value
        FROM sri_sequences
        WHERE store_id = ? AND cod_doc = ? AND estab = ? AND pto_emi = ?
        LIMIT 1
        ''',
        [storeId, codDoc, estab, ptoEmi],
      );
      final nextValue = rows.isEmpty
          ? 1
          : (rows.first['current_value'] as num).toInt() + 1;
      if (nextValue > 999999999) {
        throw StateError('Se agotó el secuencial de facturas de este local.');
      }
      await txn.rawInsert(
        '''
        INSERT INTO sri_sequences (
          store_id, cod_doc, estab, pto_emi, current_value, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(store_id, cod_doc, estab, pto_emi)
        DO UPDATE SET current_value = excluded.current_value,
                      updated_at = excluded.updated_at
        ''',
        [
          storeId,
          codDoc,
          estab,
          ptoEmi,
          nextValue,
          DateTime.now().toIso8601String(),
        ],
      );
      return nextValue;
    });
  }

  static String generateAccessKey({
    required String ruc,
    required String documentCode,
    required int ambiente,
    required String estab,
    required String ptoEmi,
    required int sequence,
    required DateTime date,
    String? codigoNumerico,
    String tipoEmision = '1',
  }) {
    final normalizedRuc = ruc.trim();
    final normalizedDocument = documentCode.trim();
    final normalizedEstab = estab.trim();
    final normalizedPoint = ptoEmi.trim();
    final numericCode =
        codigoNumerico ??
        _secureRandom.nextInt(100000000).toString().padLeft(8, '0');
    if (!RegExp(r'^\d{13}$').hasMatch(normalizedRuc)) {
      throw ArgumentError('El RUC emisor debe contener 13 dígitos.');
    }
    if (!RegExp(r'^\d{2}$').hasMatch(normalizedDocument)) {
      throw ArgumentError('El código de comprobante debe tener 2 dígitos.');
    }
    if (ambiente != 1 && ambiente != 2) {
      throw ArgumentError('El ambiente SRI debe ser 1 o 2.');
    }
    if (!RegExp(r'^\d{3}$').hasMatch(normalizedEstab) ||
        !RegExp(r'^\d{3}$').hasMatch(normalizedPoint)) {
      throw ArgumentError(
        'El establecimiento y punto de emisión deben tener 3 dígitos.',
      );
    }
    if (sequence < 1 || sequence > 999999999) {
      throw ArgumentError('El secuencial debe tener entre 1 y 999999999.');
    }
    if (!RegExp(r'^\d{8}$').hasMatch(numericCode)) {
      throw ArgumentError('El código numérico debe contener 8 dígitos.');
    }
    if (!RegExp(r'^\d$').hasMatch(tipoEmision)) {
      throw ArgumentError('El tipo de emisión debe ser un dígito.');
    }

    final dateString =
        '${date.day.toString().padLeft(2, '0')}${date.month.toString().padLeft(2, '0')}${date.year}';
    final body =
        '$dateString$normalizedDocument$normalizedRuc$ambiente$normalizedEstab$normalizedPoint${sequence.toString().padLeft(9, '0')}$numericCode$tipoEmision';
    return '$body${calculateModulo11(body)}';
  }

  static int calculateModulo11(String digits) {
    if (digits.isEmpty || !RegExp(r'^\d+$').hasMatch(digits)) {
      throw ArgumentError('El módulo 11 requiere una cadena de dígitos.');
    }
    var factor = 2;
    var total = 0;
    for (var index = digits.length - 1; index >= 0; index--) {
      total += int.parse(digits[index]) * factor;
      factor = factor == 7 ? 2 : factor + 1;
    }
    final checkDigit = 11 - (total % 11);
    if (checkDigit == 11) return 0;
    if (checkDigit == 10) return 1;
    return checkDigit;
  }

  static Future<int> _persistEmissionRecord({
    required int storeId,
    required int saleId,
    required int? clientId,
    required SriStoreConfig config,
  }) async {
    final db = await DatabaseService.database;
    final now = DateTime.now().toIso8601String();
    return db.rawInsert(
      '''
      INSERT INTO electronic_invoices (
        store_id, sale_id, client_id, document_code, clave_acceso, estado,
        ambiente, xml, authorization_number, error_message, created_at, updated_at
      ) VALUES (?, ?, ?, ?, '', 'PENDIENTE', ?, '', NULL, NULL, ?, ?)
      ''',
      [
        storeId,
        saleId,
        clientId,
        config.facturaTipo,
        config.ambiente,
        now,
        now,
      ],
    );
  }

  static Future<void> _updateInvoice({
    required int invoiceId,
    required String accessKey,
    required String state,
    String? xml,
    String? errorMessage,
    String? authorizationNumber,
    DateTime? authorizationDate,
  }) async {
    final db = await DatabaseService.database;
    await db.rawUpdate(
      '''
      UPDATE electronic_invoices SET
        clave_acceso = ?,
        estado = ?,
        xml = COALESCE(?, xml),
        error_message = ?,
        authorization_number = COALESCE(?, authorization_number),
        authorization_date = COALESCE(?, authorization_date),
        updated_at = ?
      WHERE id = ?
      ''',
      [
        accessKey,
        state,
        xml,
        errorMessage,
        authorizationNumber,
        authorizationDate?.toIso8601String(),
        DateTime.now().toIso8601String(),
        invoiceId,
      ],
    );
  }

  static String _safeErrorMessage(Object error, SriStoreConfig config) {
    var message = error.toString();
    if (config.pathP12.isNotEmpty) {
      message = message.replaceAll(config.pathP12, '[ruta del certificado]');
    }
    if (config.p12Password.isNotEmpty) {
      message = message.replaceAll(config.p12Password, '[contraseña oculta]');
    }
    if (message.startsWith('Unsupported operation:')) {
      return message.replaceFirst('Unsupported operation:', '').trim();
    }
    return 'No se pudo emitir la factura: $message';
  }

  static String _emissionTypeCode(String configuredValue) {
    final normalized = configuredValue.trim().toLowerCase();
    if (normalized == '1' ||
        normalized == 'normal' ||
        normalized == 'emisión normal' ||
        normalized == 'emision normal') {
      return '1';
    }
    if (normalized == '2' ||
        normalized == 'contingencia' ||
        normalized == 'emisión por indisponibilidad' ||
        normalized == 'emision por indisponibilidad') {
      return '2';
    }
    throw ArgumentError('Tipo de emisión SRI no reconocido.');
  }

  static void _xmlText(XmlBuilder builder, String name, String value) {
    builder.element(name, nest: () => builder.text(value));
  }

  static double _asDouble(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static double _money(double amount) => (amount * 100).roundToDouble() / 100;

  static String _formatMoney(double amount) =>
      _money(amount).toStringAsFixed(2);

  static String _formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toStringAsFixed(0);
    }
    return quantity.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '');
  }
}
