class SriSequenceModel {
  const SriSequenceModel({
    required this.id,
    required this.storeId,
    required this.codDoc,
    required this.estab,
    required this.ptoEmi,
    required this.currentValue,
    required this.updatedAt,
  });

  final int id;
  final int storeId;
  final String codDoc;
  final String estab;
  final String ptoEmi;
  final int currentValue;
  final DateTime updatedAt;

  factory SriSequenceModel.fromMap(Map<String, dynamic> row) {
    return SriSequenceModel(
      id: (row['id'] as num?)?.toInt() ?? 0,
      storeId: (row['store_id'] as num?)?.toInt() ?? 0,
      codDoc: (row['cod_doc'] as String?) ?? '01',
      estab: (row['estab'] as String?) ?? '001',
      ptoEmi: (row['pto_emi'] as String?) ?? '001',
      currentValue: (row['current_value'] as num?)?.toInt() ?? 1,
      updatedAt:
          DateTime.tryParse((row['updated_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}
