import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../Model/sri_store_config_model.dart';
import '../Utils/supplier_ruc_validator.dart';
import 'audit_service.dart';
import 'database_service.dart';
import 'sri_config_service.dart';
import 'sri_signer.dart';

class SriEmitResult {
  const SriEmitResult({
    required this.status,
    this.message = '',
    this.electronicInvoiceId,
  });

  final String status;
  final String message;
  final int? electronicInvoiceId;

  bool get isSuccess => status == 'AUTORIZADO' || status == 'RECIBIDO';
}

class SriInvoiceService {
  static bool get isGlobalEnabled =>
      (dotenv.env['SRI_ENABLED'] ?? 'false').trim().toLowerCase() == 'true';

  static Future<List<Map<String, Object?>>> getInvoicesForStore(
    int storeId,
  ) async {
    final db = await DatabaseService.database;
    return db.query(
      'electronic_invoices',
      columns: [
        'id',
        'sale_id',
        'document_code',
        'clave_acceso',
        'estado',
        'authorization_number',
        'error_message',
        'created_at',
        'updated_at',
      ],
      where: 'store_id = ?',
      whereArgs: [storeId],
      orderBy: 'created_at DESC, id DESC',
    );
  }

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
    if (config == null || !config.sriEnabled) {
      return const SriEmitResult(
        status: 'SKIPPED',
        message: 'El SRI no está habilitado para este local.',
      );
    }
    if (!config.autoEmitOnCheckout) {
      return const SriEmitResult(
        status: 'SKIPPED',
        message: 'La emisión automática está desactivada para este local.',
      );
    }

    final db = await DatabaseService.database;
    final existingRows = await db.rawQuery(
      'SELECT id, estado FROM electronic_invoices WHERE sale_id = ? AND store_id = ? LIMIT 1',
      [saleId, storeId],
    );
    if (existingRows.isNotEmpty) {
      final existingId = (existingRows.first['id'] as num).toInt();
      if (existingRows.first['estado'] == 'AUTORIZADO') {
        return SriEmitResult(
          status: 'AUTORIZADO',
          message: 'La factura de esta venta ya está autorizada.',
          electronicInvoiceId: existingId,
        );
      }
      return retry(electronicInvoiceId: existingId, storeId: storeId);
    }

    final recordId = await _persistEmissionRecord(
      storeId: storeId,
      saleId: saleId,
      config: config,
    );

    if (!SriSignerFactory.create().isSupported) {
      const message = 'Firma electrónica no soportada en esta plataforma';
      await _updateInvoiceState(
        invoiceId: recordId,
        storeId: storeId,
        state: 'ERROR',
        errorMessage: message,
      );
      return SriEmitResult(
        status: 'ERROR',
        message: message,
        electronicInvoiceId: recordId,
      );
    }

    final validationError = SriConfigService.validateConfig(config);
    if (validationError.isNotEmpty) {
      await _updateInvoiceState(
        invoiceId: recordId,
        storeId: storeId,
        state: 'ERROR',
        errorMessage: validationError,
      );
      return SriEmitResult(
        status: 'ERROR',
        message: validationError,
        electronicInvoiceId: recordId,
      );
    }

    if (config.ambiente != 1) {
      const message =
          'La emisión SRI en producción aún no está habilitada. Usa ambiente de pruebas.';
      await _updateInvoiceState(
        invoiceId: recordId,
        storeId: storeId,
        state: 'ERROR',
        errorMessage: message,
      );
      return SriEmitResult(
        status: 'ERROR',
        message: message,
        electronicInvoiceId: recordId,
      );
    }

    const message =
        'Emisión detenida: falta configurar una tarifa de IVA verificable para cada producto vendido para calcular la base imponible del XML. La venta quedó registrada y no se consumió secuencial.';
    await _updateInvoiceState(
      invoiceId: recordId,
      storeId: storeId,
      state: 'ERROR',
      errorMessage: message,
    );
    await AuditService.log(
      action: 'SRI_EMIT_BLOCKED',
      module: 'SRI',
      page: 'POS',
      entity: 'electronic_invoices',
      entityId: recordId,
      description: 'Emisión detenida por tarifas de IVA no configuradas.',
      metadata: {'store_id': storeId, 'sale_id': saleId},
      controller: 'SriInvoiceService',
      success: false,
      error: message,
    );

    return SriEmitResult(
      status: 'ERROR',
      message: message,
      electronicInvoiceId: recordId,
    );
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
    if (config == null || !config.sriEnabled) {
      return const SriEmitResult(
        status: 'ERROR',
        message: 'El local no tiene SRI activo.',
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

    final existing = rows.first;
    final status = (existing['estado'] as String?) ?? 'PENDIENTE';
    if (status == 'AUTORIZADO') {
      return const SriEmitResult(
        status: 'AUTORIZADO',
        message: 'El comprobante ya está autorizado.',
      );
    }

    final configError = SriConfigService.validateConfig(config);
    final message = !SriSignerFactory.create().isSupported
        ? 'Firma electrónica no soportada en esta plataforma'
        : configError.isNotEmpty
        ? configError
        : config.ambiente != 1
        ? 'La emisión SRI en producción aún no está habilitada. Usa ambiente de pruebas.'
        : 'No se puede reintentar: falta una tarifa de IVA verificable por cada producto para construir el XML tributario.';
    await _updateInvoiceState(
      invoiceId: electronicInvoiceId,
      storeId: storeId,
      state: 'ERROR',
      errorMessage: message,
    );
    return SriEmitResult(
      status: 'ERROR',
      message: message,
      electronicInvoiceId: electronicInvoiceId,
    );
  }

  static String validateCustomerData({
    String? ruc,
    String? cedula,
    String? identificationNumber,
    String? identificationType,
    bool consumerFinal = false,
    double? total,
  }) {
    final normalizedRuc = (ruc ?? '').trim();
    final normalizedCedula = (cedula ?? '').trim();
    final normalizedType = _normalizeSriIdentificationType(identificationType);

    if (consumerFinal) {
      if (total == null || total < 0) {
        return 'Falta el total de la factura para validar consumidor final.';
      }
      return total <= 50
          ? ''
          : 'Consumidor final solo puede usarse hasta USD 50.';
    }

    final normalizedIdentificationNumber = (identificationNumber ?? '').trim();
    final identification = normalizedIdentificationNumber.isNotEmpty
        ? normalizedIdentificationNumber
        : normalizedRuc.isNotEmpty
        ? normalizedRuc
        : normalizedCedula;
    switch (normalizedType) {
      case '04':
        return SupplierRucValidator.isValidRuc(identification)
            ? ''
            : 'El RUC del comprador no es válido.';
      case '05':
        return SupplierRucValidator.isValidCedula(identification)
            ? ''
            : 'La cédula del comprador no es válida.';
      case '06':
      case '08':
        return identification.isNotEmpty
            ? ''
            : 'La identificación del comprador es obligatoria.';
      default:
        return 'Selecciona un tipo de identificación válido para el comprador.';
    }
  }

  static String _normalizeSriIdentificationType(String? value) {
    final type = (value ?? '').trim().toLowerCase();
    return switch (type) {
      '04' || 'ruc' => '04',
      '05' || 'cedula' || 'cédula' => '05',
      '06' || 'pasaporte' || 'passport' => '06',
      '08' ||
      'identificacion exterior' ||
      'identificación exterior' ||
      'identificacion del exterior' ||
      'identificación del exterior' ||
      'foreign_id' => '08',
      _ => '',
    };
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
    final identificationType = customer == null
        ? '07'
        : _normalizeSriIdentificationType(
            customer['identification_type'] as String?,
          );
    final customerName = customer == null
        ? 'CONSUMIDOR FINAL'
        : [
            customer['name']?.toString().trim() ?? '',
            customer['apellidos']?.toString().trim() ?? '',
          ].where((part) => part.isNotEmpty).join(' ');
    final customerId = customer == null
        ? '9999999999999'
        : ((customer['cedula'] as String?) ??
                  (customer['identification_number'] as String?) ??
                  '')
              .trim();

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
      'cliente_tipo_identificacion': identificationType,
      'cliente_direccion': customer?['address']?.toString().trim() ?? '',
      'total': total,
      'fecha': sale['date'] ?? DateTime.now().toIso8601String(),
      'items': items,
    };
  }

  static Future<int> nextSequence(
    int storeId, {
    required String codDoc,
    required String estab,
    required String ptoEmi,
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

      final currentValue = rows.isEmpty
          ? 1
          : (rows.first['current_value'] as num).toInt() + 1;

      await txn.rawInsert(
        '''
        INSERT INTO sri_sequences (store_id, cod_doc, estab, pto_emi, current_value, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(store_id, cod_doc, estab, pto_emi)
        DO UPDATE SET current_value = excluded.current_value, updated_at = excluded.updated_at
        ''',
        [
          storeId,
          codDoc,
          estab,
          ptoEmi,
          currentValue,
          DateTime.now().toIso8601String(),
        ],
      );

      return currentValue;
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
  }) {
    final issueDate = DateTime(date.year, date.month, date.day);
    final normalizedRuc = ruc.trim();
    final normalizedDocumentCode = documentCode.trim().padLeft(2, '0');
    final normalizedEstab = estab.trim().padLeft(3, '0');
    final normalizedPtoEmi = ptoEmi.trim().padLeft(3, '0');
    final sequential = sequence.toString().padLeft(9, '0');
    final dateString =
        '${issueDate.day.toString().padLeft(2, '0')}${issueDate.month.toString().padLeft(2, '0')}${issueDate.year}';
    final randomDigits = _randomAccessKeyDigits();
    final typeEmission = '1';
    final base =
        '$dateString$normalizedDocumentCode$normalizedRuc$ambiente$normalizedEstab$normalizedPtoEmi$sequential$randomDigits$typeEmission';
    final code = _calculateModulo11(base);
    return '$base$code';
  }

  static bool isValidAccessKey(String accessKey) {
    if (accessKey.trim().length != 49) return false;
    if (!RegExp(r'^\d{49}$').hasMatch(accessKey.trim())) return false;
    final base = accessKey.substring(0, 48);
    final checkDigit = accessKey.substring(48);
    final calculated = _calculateModulo11(base).toString();
    return checkDigit == calculated;
  }

  static String _randomAccessKeyDigits() =>
      Random.secure().nextInt(100000000).toString().padLeft(8, '0');

  static int _calculateModulo11(String digits) {
    final parsed = digits.split('').map(int.parse).toList();
    int weight = 2;
    int total = 0;
    for (int i = parsed.length - 1; i >= 0; i--) {
      total += parsed[i] * weight;
      weight = weight == 7 ? 2 : weight + 1;
    }

    final remainder = total % 11;
    final result = 11 - remainder;
    if (result == 11) return 0;
    if (result == 10) return 1;
    return result;
  }

  static Future<int> _persistEmissionRecord({
    required int storeId,
    required int saleId,
    required SriStoreConfig config,
  }) async {
    final db = await DatabaseService.database;
    final saleRows = await db.rawQuery(
      'SELECT id, client_id FROM sales WHERE id = ? AND store_id = ? LIMIT 1',
      [saleId, storeId],
    );
    if (saleRows.isEmpty) {
      throw StateError('La venta no pertenece al local seleccionado.');
    }

    final invoiceId = await db.rawInsert(
      '''
      INSERT INTO electronic_invoices (
        store_id, sale_id, client_id, document_code, clave_acceso, estado, ambiente,
        xml, authorization_number, error_message, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, 'PENDIENTE', ?, ?, NULL, NULL, ?, ?)
      ''',
      [
        storeId,
        saleId,
        saleRows.first['client_id'],
        config.facturaTipo,
        '',
        config.ambiente,
        '',
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
    await db.rawUpdate(
      'UPDATE sales SET electronic_invoice_id = ?, sri_status = ? WHERE id = ? AND store_id = ?',
      [invoiceId, 'PENDIENTE', saleId, storeId],
    );
    return invoiceId;
  }

  static Future<void> _updateInvoiceState({
    required int invoiceId,
    required int storeId,
    required String state,
    String? errorMessage,
  }) async {
    final db = await DatabaseService.database;
    await db.rawUpdate(
      '''
      UPDATE electronic_invoices
      SET estado = ?, error_message = ?, updated_at = ?
      WHERE id = ? AND store_id = ?
      ''',
      [
        state,
        errorMessage,
        DateTime.now().toIso8601String(),
        invoiceId,
        storeId,
      ],
    );
    await db.rawUpdate(
      '''
      UPDATE sales
      SET sri_status = ?
      WHERE store_id = ?
        AND id = (
          SELECT sale_id FROM electronic_invoices
          WHERE id = ? AND store_id = ?
        )
      ''',
      [state, storeId, invoiceId, storeId],
    );
  }
}
