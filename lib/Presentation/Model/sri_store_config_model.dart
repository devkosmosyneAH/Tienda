class SriStoreConfig {
  const SriStoreConfig({
    required this.id,
    required this.storeId,
    required this.sriEnabled,
    required this.autoEmitOnCheckout,
    required this.ambiente,
    required this.ruc,
    required this.razonSocial,
    required this.nombreComercial,
    required this.direccionMatriz,
    required this.codigoEstablecimiento,
    required this.puntoEmision,
    required this.tipoEmision,
    required this.pathP12,
    required this.p12Password,
    required this.facturaTipo,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int storeId;
  final bool sriEnabled;
  final bool autoEmitOnCheckout;
  final int ambiente;
  final String ruc;
  final String razonSocial;
  final String nombreComercial;
  final String direccionMatriz;
  final String codigoEstablecimiento;
  final String puntoEmision;
  final String tipoEmision;
  final String pathP12;
  final String p12Password;
  final String facturaTipo;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isComplete {
    return sriEnabled &&
        ruc.trim().length == 13 &&
        razonSocial.trim().isNotEmpty &&
        direccionMatriz.trim().isNotEmpty &&
        RegExp(r'^\d{3}$').hasMatch(codigoEstablecimiento.trim()) &&
        RegExp(r'^\d{3}$').hasMatch(puntoEmision.trim()) &&
        pathP12.trim().isNotEmpty &&
        p12Password.trim().isNotEmpty;
  }

  factory SriStoreConfig.fromMap(Map<String, dynamic> row) {
    return SriStoreConfig(
      id: (row['id'] as num?)?.toInt() ?? 0,
      storeId: (row['store_id'] as num?)?.toInt() ?? 0,
      sriEnabled: (row['sri_enabled'] as num?)?.toInt() == 1,
      autoEmitOnCheckout: (row['auto_emit_on_checkout'] as num?)?.toInt() == 1,
      ambiente: (row['ambiente'] as num?)?.toInt() ?? 1,
      ruc: (row['ruc'] as String?) ?? '',
      razonSocial: (row['razon_social'] as String?) ?? '',
      nombreComercial: (row['nombre_comercial'] as String?) ?? '',
      direccionMatriz: (row['direccion_matriz'] as String?) ?? '',
      codigoEstablecimiento: (row['codigo_establecimiento'] as String?) ?? '',
      puntoEmision: (row['punto_emision'] as String?) ?? '',
      tipoEmision: (row['tipo_emision'] as String?) ?? '',
      pathP12: (row['path_p12'] as String?) ?? '',
      p12Password: (row['p12_password'] as String?) ?? '',
      facturaTipo: (row['factura_tipo'] as String?) ?? '01',
      createdAt:
          DateTime.tryParse((row['created_at'] as String?) ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((row['updated_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'store_id': storeId,
      'sri_enabled': sriEnabled ? 1 : 0,
      'auto_emit_on_checkout': autoEmitOnCheckout ? 1 : 0,
      'ambiente': ambiente,
      'ruc': ruc,
      'razon_social': razonSocial,
      'nombre_comercial': nombreComercial,
      'direccion_matriz': direccionMatriz,
      'codigo_establecimiento': codigoEstablecimiento,
      'punto_emision': puntoEmision,
      'tipo_emision': tipoEmision,
      'path_p12': pathP12,
      'p12_password': p12Password,
      'factura_tipo': facturaTipo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
