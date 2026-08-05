enum PurchaseStatus {
  pending('Pendiente'),
  received('Recibida'),
  partiallyReceived('Recibida Parcialmente'),
  cancelled('Cancelada');

  final String display;
  const PurchaseStatus(this.display);
}

class PurchaseItem {
  final int productId;
  final String productName;
  final int orderedQuantity;
  final int receivedQuantity;
  final double unitCost;
  final double totalCost;

  PurchaseItem({
    required this.productId,
    required this.productName,
    required this.orderedQuantity,
    required this.receivedQuantity,
    required this.unitCost,
    required this.totalCost,
  });

  int get pendingQuantity => orderedQuantity - receivedQuantity;
  bool get isCompletelyReceived => pendingQuantity == 0;

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      productId: (map['product_id'] as num).toInt(),
      productName: map['product_name'] as String,
      orderedQuantity: (map['ordered_quantity'] as num).toInt(),
      receivedQuantity: (map['received_quantity'] as num?)?.toInt() ?? 0,
      unitCost: (map['unit_cost'] as num).toDouble(),
      totalCost: (map['total_cost'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'ordered_quantity': orderedQuantity,
      'received_quantity': receivedQuantity,
      'unit_cost': unitCost,
      'total_cost': totalCost,
    };
  }
}

class Purchase {
  final int id;
  final int supplierId;
  final String supplierName;
  final int storeId;
  final List<PurchaseItem> items;
  final double subtotal;
  final double tax;
  final double total;
  final double? amountPaid;
  final String? invoiceNumber;
  final String? referenceNumber;
  final String? notes;
  final PurchaseStatus status;
  final DateTime orderDate;
  final DateTime? expectedDeliveryDate;
  final DateTime? deliveryDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Purchase({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.storeId,
    required this.items,
    required this.subtotal,
    this.tax = 0.0,
    required this.total,
    this.amountPaid,
    this.invoiceNumber,
    this.referenceNumber,
    this.notes,
    this.status = PurchaseStatus.pending,
    required this.orderDate,
    this.expectedDeliveryDate,
    this.deliveryDate,
    required this.createdAt,
    this.updatedAt,
  });

  int get totalItems => items.fold(0, (sum, item) => sum + item.orderedQuantity);
  int get receivedItems =>
      items.fold(0, (sum, item) => sum + item.receivedQuantity);

  double get pendingAmount => total - (amountPaid ?? 0.0);
  bool get isPaidInFull => (amountPaid ?? 0.0) >= total;

  Purchase copyWith({
    int? id,
    int? supplierId,
    String? supplierName,
    int? storeId,
    List<PurchaseItem>? items,
    double? subtotal,
    double? tax,
    double? total,
    double? amountPaid,
    String? invoiceNumber,
    String? referenceNumber,
    String? notes,
    PurchaseStatus? status,
    DateTime? orderDate,
    DateTime? expectedDeliveryDate,
    DateTime? deliveryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Purchase(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      storeId: storeId ?? this.storeId,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      amountPaid: amountPaid ?? this.amountPaid,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      orderDate: orderDate ?? this.orderDate,
      expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Purchase.fromMap(Map<String, dynamic> map) {
    return Purchase(
      id: (map['id'] as num).toInt(),
      supplierId: (map['supplier_id'] as num).toInt(),
      supplierName: map['supplier_name'] as String,
      storeId: (map['store_id'] as num).toInt(),
      items: (map['items'] as List<dynamic>?)
              ?.map((e) => PurchaseItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (map['subtotal'] as num).toDouble(),
      tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num).toDouble(),
      amountPaid: (map['amount_paid'] as num?)?.toDouble(),
      invoiceNumber: map['invoice_number'] as String?,
      referenceNumber: map['reference_number'] as String?,
      notes: map['notes'] as String?,
      status: PurchaseStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'pending'),
        orElse: () => PurchaseStatus.pending,
      ),
      orderDate: map['order_date'] != null
          ? DateTime.parse(map['order_date'] as String)
          : DateTime.now(),
      expectedDeliveryDate: map['expected_delivery_date'] != null
          ? DateTime.parse(map['expected_delivery_date'] as String)
          : null,
      deliveryDate: map['delivery_date'] != null
          ? DateTime.parse(map['delivery_date'] as String)
          : null,
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
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'store_id': storeId,
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'amount_paid': amountPaid,
      'invoice_number': invoiceNumber,
      'reference_number': referenceNumber,
      'notes': notes,
      'status': status.name,
      'order_date': orderDate.toIso8601String(),
      'expected_delivery_date': expectedDeliveryDate?.toIso8601String(),
      'delivery_date': deliveryDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
