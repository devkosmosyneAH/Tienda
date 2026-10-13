import 'dart:convert';

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
    this.authorizationDate,
    required this.errorMessage,
    this.errorType,
    this.errorIdentifier,
    this.sriMessages = const [],
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
  final DateTime? authorizationDate;
  final String? errorMessage;
  final String? errorType;
  final String? errorIdentifier;
  final List<SriInvoiceMessage> sriMessages;
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
      authorizationDate: DateTime.tryParse(
        (row['authorization_date'] as String?) ?? '',
      ),
      errorMessage: row['error_message'] as String?,
      errorType: row['error_type'] as String?,
      errorIdentifier: row['error_identifier'] as String?,
      sriMessages: _parseSriMessages(row['sri_messages'] as String?),
      createdAt:
          DateTime.tryParse((row['created_at'] as String?) ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((row['updated_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  static List<SriInvoiceMessage> _parseSriMessages(String? value) {
    if (value == null || value.isEmpty) return const [];
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      throw const FormatException(
        'Los mensajes SRI guardados no son una lista.',
      );
    }
    return decoded
        .map((message) {
          if (message is! Map<String, dynamic>) {
            throw const FormatException(
              'Un mensaje SRI guardado no es válido.',
            );
          }
          return SriInvoiceMessage.fromMap(message);
        })
        .toList();
  }
}

class SriInvoiceMessage {
  const SriInvoiceMessage({
    required this.identifier,
    required this.message,
    required this.additionalInformation,
    required this.type,
  });

  final String identifier;
  final String message;
  final String? additionalInformation;
  final String type;

  factory SriInvoiceMessage.fromMap(Map<String, dynamic> map) {
    return SriInvoiceMessage(
      identifier: map['identificador'] as String? ?? '',
      message: map['mensaje'] as String? ?? '',
      additionalInformation: map['informacionAdicional'] as String?,
      type: map['tipo'] as String? ?? '',
    );
  }
}
