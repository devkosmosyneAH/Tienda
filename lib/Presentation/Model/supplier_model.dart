class SupplierModel {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;
  final String? ruc;

  const SupplierModel({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.notes,
    this.ruc,
  });

  factory SupplierModel.fromMap(Map<String, dynamic> map) {
    return SupplierModel(
      id: (map['id'] as num?)?.toInt(),
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      notes: map['notes'] as String?,
      ruc: map['ruc'] as String?,
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
    };
  }

  SupplierModel copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? notes,
    String? ruc,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      ruc: ruc ?? this.ruc,
    );
  }
}
