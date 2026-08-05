class Product {
  final int id;
  final String? uid;
  final String name;
  final String? description;
  final String? tags;
  final double price;
  final double costPrice;
  final double ivaRate;
  final double profitIva;
  final int quantity;
  final int minStock;
  final String? category;
  final String? sku;
  final String? auxCode;
  final String? barcode;
  final int? storeId;
  final String? storeName;
  final List<String> images;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    this.uid,
    required this.name,
    this.description,
    this.tags,
    required this.price,
    required this.costPrice,
    this.ivaRate = 0,
    this.profitIva = 0,
    required this.quantity,
    required this.minStock,
    this.category,
    this.sku,
    this.auxCode,
    this.barcode,
    this.storeId,
    this.storeName,
    this.images = const [],
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// Calcula el margen de ganancia
  double get profitMargin {
    if (costPrice == 0) return 0;
    return ((price - costPrice) / costPrice) * 100;
  }

  /// Verifica si está bajo stock
  bool get isLowStock => quantity <= minStock;

  /// Valor total del inventario
  double get totalInventoryValue => quantity * costPrice;

  /// Crea una copia con cambios
  Product copyWith({
    int? id,
    String? uid,
    String? name,
    String? description,
    String? tags,
    double? price,
    double? costPrice,
    double? ivaRate,
    double? profitIva,
    int? quantity,
    int? minStock,
    String? category,
    String? sku,
    String? auxCode,
    String? barcode,
    int? storeId,
    String? storeName,
    List<String>? images,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      ivaRate: ivaRate ?? this.ivaRate,
      profitIva: profitIva ?? this.profitIva,
      quantity: quantity ?? this.quantity,
      minStock: minStock ?? this.minStock,
      category: category ?? this.category,
      sku: sku ?? this.sku,
      auxCode: auxCode ?? this.auxCode,
      barcode: barcode ?? this.barcode,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      images: images ?? this.images,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convierte de Map a Product
  factory Product.fromMap(Map<String, dynamic> map) {
    final rawImages = map['images'] as String?;
    return Product(
      id: (map['id'] as num).toInt(),
      uid: map['uid'] as String?,
      name: map['name'] as String,
      description: map['description'] as String?,
      tags: map['tags'] as String?,
      price: (map['price'] as num).toDouble(),
      costPrice: ((map['costPrice'] ?? map['cost_price']) as num).toDouble(),
      ivaRate: ((map['ivaRate'] ?? map['iva_rate'] ?? 0) as num).toDouble(),
      profitIva: ((map['profitIva'] ?? map['profit_iva'] ?? 0) as num)
          .toDouble(),
      quantity: ((map['quantity'] ?? map['total_stock'] ?? 0) as num).toInt(),
      minStock: ((map['minStock'] ?? map['min_stock'] ?? 0) as num).toInt(),
      category: map['category'] as String?,
      sku: map['sku'] as String?,
      auxCode: map['aux_code'] as String?,
      barcode: map['barcode'] as String?,
      storeId: (map['store_id'] as num?)?.toInt(),
      storeName: map['store_name'] as String?,
      images: (rawImages != null && rawImages.isNotEmpty)
          ? rawImages.split(',')
          : const [],
      isActive: ((map['isActive'] ?? map['is_active']) as bool?) ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Convierte Product a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'name': name,
      'description': description,
      'tags': tags,
      'price': price,
      'cost_price': costPrice,
      'iva_rate': ivaRate,
      'profit_iva': profitIva,
      'quantity': quantity,
      'min_stock': minStock,
      'category': category,
      'sku': sku,
      'aux_code': auxCode,
      'barcode': barcode,
      'store_id': storeId,
      'images': images.isEmpty ? null : images.join(','),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'Product(id: $id, uid: $uid, name: $name, price: $price)';
}
