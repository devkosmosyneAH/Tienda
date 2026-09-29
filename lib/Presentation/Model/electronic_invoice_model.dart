class ElectronicInvoiceModel {
  const ElectronicInvoiceModel({
    required this.id,
    required this.storeId,
    required this.saleId,
    required this.clientId,
    required this.documentCode,
    required this.claveAcceso,
    required this.state,
    required this.ambiente,
    required this.xml,
    required this.authorizationNumber,
    required this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int storeId;
  final int saleId;
  final int? clientId;
  final String documentCode;
  final String claveAcceso;
  final String state;
  final int ambiente;
  final String xml;
  final String? authorizationNumber;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ElectronicInvoiceModel.fromMap(Map<String, dynamic> row) {
    return ElectronicInvoiceModel(
      id: (row['id'] as num?)?.toInt() ?? 0,
      storeId: (row['store_id'] as num?)?.toInt() ?? 0,
      saleId: (row['sale_id'] as num?)?.toInt() ?? 0,
      clientId: (row['client_id'] as num?)?.toInt(),
      documentCode: (row['document_code'] as String?) ?? '01',
      claveAcceso: (row['clave_acceso'] as String?) ?? '',
      state: (row['estado'] as String?) ?? 'PENDIENTE',
      ambiente: (row['ambiente'] as num?)?.toInt() ?? 1,
      xml: (row['xml'] as String?) ?? '',
      authorizationNumber: row['authorization_number'] as String?,
      errorMessage: row['error_message'] as String?,
      createdAt:
          DateTime.tryParse((row['created_at'] as String?) ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((row['updated_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}
