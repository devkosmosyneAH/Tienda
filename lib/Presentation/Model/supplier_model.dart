class SupplierModel {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;
  final String? ruc;
  final String? identificationType;
  final String? identificationNumber;
  final String? legalName;
  final String? address;
  final String paymentCondition;
  final int paymentTermDays;
  final String? taxpayerType;
  final bool isWithholdingAgent;

  const SupplierModel({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.notes,
    this.ruc,
    this.identificationType,
    this.identificationNumber,
    this.legalName,
    this.address,
    this.paymentCondition = 'contado',
    this.paymentTermDays = 0,
    this.taxpayerType,
    this.isWithholdingAgent = false,
  });

  factory SupplierModel.fromMap(Map<String, dynamic> map) {
    return SupplierModel(
      id: (map['id'] as num?)?.toInt(),
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      notes: map['notes'] as String?,
      ruc: map['ruc'] as String?,
      identificationType: map['identification_type']?.toString() ?? 'ruc',
      identificationNumber:
          map['identification_number']?.toString() ?? map['ruc']?.toString(),
      legalName: map['legal_name']?.toString() ?? map['name']?.toString(),
      address: map['address'] as String?,
      paymentCondition: map['payment_condition']?.toString() ?? 'contado',
      paymentTermDays: (map['payment_term_days'] as num?)?.toInt() ?? 0,
      taxpayerType: map['taxpayer_type']?.toString(),
      isWithholdingAgent:
          ((map['is_withholding_agent'] as num?)?.toInt() ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (notes != null) 'notes': notes,
      if (ruc != null) 'ruc': ruc,
      if (identificationType != null) 'identification_type': identificationType,
      if (identificationNumber != null)
        'identification_number': identificationNumber,
      if (legalName != null) 'legal_name': legalName,
      if (address != null) 'address': address,
      'payment_condition': paymentCondition,
      'payment_term_days': paymentTermDays,
      if (taxpayerType != null) 'taxpayer_type': taxpayerType,
      'is_withholding_agent': isWithholdingAgent ? 1 : 0,
    };
  }

  SupplierModel copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? notes,
    String? ruc,
    String? identificationType,
    String? identificationNumber,
    String? legalName,
    String? address,
    String? paymentCondition,
    int? paymentTermDays,
    String? taxpayerType,
    bool? isWithholdingAgent,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      ruc: ruc ?? this.ruc,
      identificationType: identificationType ?? this.identificationType,
      identificationNumber: identificationNumber ?? this.identificationNumber,
      legalName: legalName ?? this.legalName,
      address: address ?? this.address,
      paymentCondition: paymentCondition ?? this.paymentCondition,
      paymentTermDays: paymentTermDays ?? this.paymentTermDays,
      taxpayerType: taxpayerType ?? this.taxpayerType,
      isWithholdingAgent: isWithholdingAgent ?? this.isWithholdingAgent,
    );
  }
}
