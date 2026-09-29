import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../Model/sri_store_config_model.dart';
import 'database_service.dart';

class SriConfigService {
  static bool get globalEnabled =>
      (dotenv.env['SRI_ENABLED'] ?? 'false').trim().toLowerCase() == 'true';

  static bool get autoEmitEnabled =>
      (dotenv.env['SRI_AUTO_EMIT_ON_CHECKOUT'] ?? 'false')
          .trim()
          .toLowerCase() ==
      'true';

  static int get defaultAmbiente =>
      int.tryParse(dotenv.env['SRI_DEFAULT_AMBIENTE'] ?? '1') ?? 1;

  static Future<SriStoreConfig?> getConfig(int storeId) async {
    final db = await DatabaseService.database;
    final rows = await db.rawQuery(
      'SELECT * FROM sri_store_config WHERE store_id = ? LIMIT 1',
      [storeId],
    );
    if (rows.isEmpty) return null;
    return SriStoreConfig.fromMap(rows.first);
  }

  static Future<Object> saveConfig({
    required int storeId,
    required bool sriEnabled,
    bool autoEmitOnCheckout = false,
    int ambiente = 1,
    String ruc = '',
    String razonSocial = '',
    String nombreComercial = '',
    String direccionMatriz = '',
    String codigoEstablecimiento = '001',
    String puntoEmision = '001',
    String tipoEmision = 'NORMAL',
    String pathP12 = '',
    String p12Password = '',
    String facturaTipo = '01',
  }) async {
    final db = await DatabaseService.database;
    final now = DateTime.now().toIso8601String();
    final record = SriStoreConfig(
      id: 0,
      storeId: storeId,
      sriEnabled: sriEnabled,
      autoEmitOnCheckout: autoEmitOnCheckout,
      ambiente: ambiente,
      ruc: ruc.trim(),
      razonSocial: razonSocial.trim(),
      nombreComercial: nombreComercial.trim(),
      direccionMatriz: direccionMatriz.trim(),
      codigoEstablecimiento: codigoEstablecimiento.trim().isEmpty
          ? '001'
          : codigoEstablecimiento.trim(),
      puntoEmision: puntoEmision.trim().isEmpty ? '001' : puntoEmision.trim(),
      tipoEmision: tipoEmision.trim().isEmpty ? 'NORMAL' : tipoEmision.trim(),
      pathP12: pathP12.trim(),
      p12Password: p12Password.trim(),
      facturaTipo: facturaTipo.trim().isEmpty ? '01' : facturaTipo.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final existing = await getConfig(storeId);
    if (existing == null) {
      await db.rawInsert(
        '''
        INSERT INTO sri_store_config (
          store_id, sri_enabled, auto_emit_on_checkout, ambiente, ruc,
          razon_social, nombre_comercial, direccion_matriz,
          codigo_establecimiento, punto_emision, tipo_emision,
          path_p12, p12_password, factura_tipo, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          storeId,
          record.sriEnabled ? 1 : 0,
          record.autoEmitOnCheckout ? 1 : 0,
          record.ambiente,
          record.ruc,
          record.razonSocial,
          record.nombreComercial,
          record.direccionMatriz,
          record.codigoEstablecimiento,
          record.puntoEmision,
          record.tipoEmision,
          record.pathP12,
          record.p12Password,
          record.facturaTipo,
          now,
          now,
        ],
      );
    } else {
      await db.rawUpdate(
        '''
        UPDATE sri_store_config SET
          sri_enabled = ?,
          auto_emit_on_checkout = ?,
          ambiente = ?,
          ruc = ?,
          razon_social = ?,
          nombre_comercial = ?,
          direccion_matriz = ?,
          codigo_establecimiento = ?,
          punto_emision = ?,
          tipo_emision = ?,
          path_p12 = ?,
          p12_password = ?,
          factura_tipo = ?,
          updated_at = ?
        WHERE store_id = ?
        ''',
        [
          record.sriEnabled ? 1 : 0,
          record.autoEmitOnCheckout ? 1 : 0,
          record.ambiente,
          record.ruc,
          record.razonSocial,
          record.nombreComercial,
          record.direccionMatriz,
          record.codigoEstablecimiento,
          record.puntoEmision,
          record.tipoEmision,
          record.pathP12,
          record.p12Password,
          record.facturaTipo,
          now,
          storeId,
        ],
      );
    }

    return getConfig(storeId);
  }

  static String validateConfig(SriStoreConfig? config) {
    if (config == null) return 'Falta configuración SRI para este local.';
    if (!config.sriEnabled) {
      return 'El local tiene SRI deshabilitado.';
    }
    if (config.ambiente != 1 && config.ambiente != 2) {
      return 'El ambiente SRI debe ser 1 (pruebas) o 2 (producción).';
    }
    if (config.ruc.trim().length != 13) {
      return 'El RUC del local debe tener 13 dígitos.';
    }
    if (config.codigoEstablecimiento.trim().isEmpty) {
      return 'Falta el código de establecimiento del local.';
    }
    if (config.puntoEmision.trim().isEmpty) {
      return 'Falta el punto de emisión del local.';
    }
    if (config.pathP12.trim().isEmpty || config.p12Password.trim().isEmpty) {
      return 'Falta la ruta o contraseña del certificado .p12 del local.';
    }
    return '';
  }
}
