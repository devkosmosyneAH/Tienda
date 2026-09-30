import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../Model/sri_store_config_model.dart';
import 'audit_service.dart';
import 'database_service.dart';
import 'sri_config_service.dart';

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

    try {
      final recordId = await _persistEmissionRecord(
        storeId: storeId,
        saleId: saleId,
        config: config,
      );

      final accessKey = generateAccessKey(
        ruc: config.ruc,
        documentCode: config.facturaTipo,
        ambiente: config.ambiente,
        estab: config.codigoEstablecimiento,
        ptoEmi: config.puntoEmision,
        sequence: await nextSequence(
          storeId,
          codDoc: config.facturaTipo,
          estab: config.codigoEstablecimiento,
          ptoEmi: config.puntoEmision,
        ),
        date: DateTime.now(),
      );

      await _updateInvoiceState(
        invoiceId: recordId,
        claveAcceso: accessKey,
        state: 'PENDIENTE',
      );

      await AuditService.log(
        action: 'SRI_EMIT',
        module: 'SRI',
        page: 'POS',
        entity: 'electronic_invoices',
        entityId: recordId,
        description: 'Factura SRI programada para el local $storeId',
        metadata: {
          'store_id': storeId,
          'sale_id': saleId,
          'clave_acceso': accessKey,
        },
        controller: 'SriInvoiceService',
      );

      return SriEmitResult(
        status: 'PENDIENTE',
        message: 'Factura generada localmente y pendiente de autorización.',
        electronicInvoiceId: recordId,
      );
    } catch (error) {
      await AuditService.log(
        action: 'SRI_EMIT_ERROR',
        module: 'SRI',
        page: 'POS',
        entity: 'electronic_invoices',
        entityId: saleId,
        description: 'Fallo al generar comprobante SRI',
        error: error,
        controller: 'SriInvoiceService',
      );

      return SriEmitResult(
        status: 'ERROR',
        message:
            'No se pudo emitir la factura del local. La venta quedó registrada.',
      );
    }
  }

  static Future<SriEmitResult> retry({
    required int electronicInvoiceId,
    required int storeId,
  }) async {
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

    return SriEmitResult(
      status: 'PENDIENTE',
      message: 'Reintento programado para la factura del local.',
      electronicInvoiceId: electronicInvoiceId,
    );
  }

  static String validateCustomerData({
    String? ruc,
    String? cedula,
    String? identificationType,
    bool consumerFinal = false,
  }) {
    final normalizedRuc = (ruc ?? '').trim();
    final normalizedCedula = (cedula ?? '').trim();
    final normalizedType = (identificationType ?? '').trim();

    if (consumerFinal) {
      return '';
    }

    if (normalizedRuc.isNotEmpty && normalizedRuc.length == 13) {
      return '';
    }

    if (normalizedCedula.isNotEmpty &&
        (normalizedType.isEmpty || normalizedType.toLowerCase() == 'cedula')) {
      return '';
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

  static Future<int> nextSequence(
    int storeId, {
    String codDoc = '01',
    String estab = '001',
    String ptoEmi = '001',
  }) async {
    final db = await DatabaseService.database;
    final rows = await db.rawQuery(
      '''
      SELECT current_value
      FROM sri_sequences
      WHERE store_id = ? AND cod_doc = ? AND estab = ? AND pto_emi = ?
      ORDER BY current_value DESC
      LIMIT 1
      ''',
      [storeId, codDoc, estab, ptoEmi],
    );

    final currentValue = rows.isEmpty
        ? 1
        : (rows.first['current_value'] as num).toInt() + 1;

    await db.rawInsert(
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
    final dateString =
        '${date.day.toString().padLeft(2, '0')}${date.month.toString().padLeft(2, '0')}${date.year}';
    final base =
        '$dateString${ruc.trim()}${documentCode.padLeft(2, '0')}${estab.padLeft(3, '0')}${ptoEmi.padLeft(3, '0')}${sequence.toString().padLeft(9, '0')}${ambiente}100000000';
    final code = _calculateModulo11(base);
    return '$base$code';
  }

  static int _calculateModulo11(String digits) {
    final parsed = digits.split('').map(int.parse).toList();
    int factor = 2;
    int total = 0;
    for (int i = parsed.length - 1; i >= 0; i--) {
      total += parsed[i] * factor;
      factor = factor == 7 ? 2 : factor + 1;
    }

    final remainder = total % 11;
    final result = remainder == 0 ? 0 : 11 - remainder;
    return result == 10 ? 0 : result;
  }

  static Future<int> _persistEmissionRecord({
    required int storeId,
    required int saleId,
    required SriStoreConfig config,
  }) async {
    final db = await DatabaseService.database;
    return db.rawInsert(
      '''
      INSERT INTO electronic_invoices (
        store_id, sale_id, client_id, document_code, clave_acceso, estado, ambiente,
        xml, authorization_number, error_message, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, 'PENDIENTE', ?, ?, NULL, NULL, ?, ?)
      ''',
      [
        storeId,
        saleId,
        null,
        config.facturaTipo,
        '',
        config.ambiente,
        '',
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
  }

  static Future<void> _updateInvoiceState({
    required int invoiceId,
    required String claveAcceso,
    required String state,
  }) async {
    final db = await DatabaseService.database;
    await db.rawUpdate(
      'UPDATE electronic_invoices SET clave_acceso = ?, estado = ?, updated_at = ? WHERE id = ?',
      [claveAcceso, state, DateTime.now().toIso8601String(), invoiceId],
    );
  }
}
