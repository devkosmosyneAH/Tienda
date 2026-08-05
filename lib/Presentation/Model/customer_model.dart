class Customer {
  final int id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? city;
  final String? notes;
  final double balance; // Crédito del cliente
  final int totalPurchases;
  final double totalSpent;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastPurchaseDate;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.city,
    this.notes,
    this.balance = 0.0,
    this.totalPurchases = 0,
    this.totalSpent = 0.0,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.lastPurchaseDate,
  });

  /// Verifica si tiene crédito disponible
  bool get hasBalance => balance > 0;

  /// Calcula ticket promedio
  double get averageTicket {
    if (totalPurchases == 0) return 0;
    return totalSpent / totalPurchases;
  }

  /// Copia con cambios
  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? notes,
    double? balance,
    int? totalPurchases,
    double? totalSpent,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastPurchaseDate,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      notes: notes ?? this.notes,
      balance: balance ?? this.balance,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      totalSpent: totalSpent ?? this.totalSpent,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
    );
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: (map['id'] as num).toInt(),
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      city: map['city'] as String?,
      notes: map['notes'] as String?,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      totalPurchases: (map['total_purchases'] as num?)?.toInt() ?? 0,
      totalSpent: (map['total_spent'] as num?)?.toDouble() ?? 0.0,
      isActive: (map['is_active'] as bool?) ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      lastPurchaseDate: map['last_purchase_date'] != null
          ? DateTime.parse(map['last_purchase_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'city': city,
      'notes': notes,
      'balance': balance,
      'total_purchases': totalPurchases,
      'total_spent': totalSpent,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'last_purchase_date': lastPurchaseDate?.toIso8601String(),
    };
  }

  @override
  String toString() => 'Customer(id: $id, name: $name, balance: $balance)';
}
