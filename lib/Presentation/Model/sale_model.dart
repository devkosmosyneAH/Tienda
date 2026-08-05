enum PaymentMethod {
  cash('Efectivo'),
  card('Tarjeta'),
  check('Cheque'),
  transfer('Transferencia'),
  electronicMoney('Dinero Electrónico'),
  credit('Crédito');

  final String display;
  const PaymentMethod(this.display);
}

enum SaleStatus {
  pending('Pendiente'),
  completed('Completada'),
  cancelled('Cancelada'),
  refunded('Reembolsada');

  final String display;
  const SaleStatus(this.display);
}

class SaleItem {
  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double discount; // Descuento por unidad
  final double totalPrice;

  SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0.0,
    required this.totalPrice,
  });

  double get subtotal => (unitPrice * quantity) - (discount * quantity);

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productId: (map['product_id'] as num).toInt(),
      productName: map['product_name'] as String,
      quantity: (map['quantity'] as num).toInt(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['total_price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount': discount,
      'total_price': totalPrice,
    };
  }
}

class Sale {
  final int id;
  final int customerId;
  final String customerName;
  final int storeId;
  final List<SaleItem> items;
  final double subtotal;
  final double discount; // Descuento general
  final double tax;
  final double total;
  final PaymentMethod paymentMethod;
  final String? paymentReference;
  final String? notes;
  final SaleStatus status;
  final DateTime saleDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Sale({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.storeId,
    required this.items,
    required this.subtotal,
    this.discount = 0.0,
    this.tax = 0.0,
    required this.total,
    required this.paymentMethod,
    this.paymentReference,
    this.notes,
    this.status = SaleStatus.completed,
    required this.saleDate,
    required this.createdAt,
    this.updatedAt,
  });

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  Sale copyWith({
    int? id,
    int? customerId,
    String? customerName,
    int? storeId,
    List<SaleItem>? items,
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
    PaymentMethod? paymentMethod,
    String? paymentReference,
    String? notes,
    SaleStatus? status,
    DateTime? saleDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Sale(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      storeId: storeId ?? this.storeId,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentReference: paymentReference ?? this.paymentReference,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      saleDate: saleDate ?? this.saleDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: (map['id'] as num).toInt(),
      customerId: (map['customer_id'] as num).toInt(),
      customerName: map['customer_name'] as String,
      storeId: (map['store_id'] as num).toInt(),
      items: (map['items'] as List<dynamic>?)
              ?.map((e) => SaleItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num).toDouble(),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == map['payment_method'],
        orElse: () => PaymentMethod.cash,
      ),
      paymentReference: map['payment_reference'] as String?,
      notes: map['notes'] as String?,
      status: SaleStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'completed'),
        orElse: () => SaleStatus.completed,
      ),
      saleDate: map['sale_date'] != null
          ? DateTime.parse(map['sale_date'] as String)
          : DateTime.now(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'customer_name': customerName,
      'store_id': storeId,
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'payment_method': paymentMethod.name,
      'payment_reference': paymentReference,
      'notes': notes,
      'status': status.name,
      'sale_date': saleDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
