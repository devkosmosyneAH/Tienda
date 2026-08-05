class InventoryItem {
  final int productId;
  final String name;
  final String sku;
  final String category;
  final double sellPrice;
  final double costPrice;
  final int quantity;
  final int unitsSold; // Unidades vendidas en período
  final double investmentValue; // Inversión en este stock
  final double potentialGain; // Ganancia si se vende todo
  final double marginPerUnit;

  InventoryItem({
    required this.productId,
    required this.name,
    required this.sku,
    required this.category,
    required this.sellPrice,
    required this.costPrice,
    required this.quantity,
    this.unitsSold = 0,
    double? investmentValue,
    double? potentialGain,
    double? marginPerUnit,
  }) : investmentValue = investmentValue ?? (costPrice * quantity),
       potentialGain = potentialGain ?? ((sellPrice - costPrice) * quantity),
       marginPerUnit = marginPerUnit ?? (sellPrice - costPrice);

  /// Margen de ganancia en porcentaje
  double get marginPercent {
    if (costPrice == 0) return 0;
    return ((sellPrice - costPrice) / costPrice) * 100;
  }

  /// Stock es bajo si está bajo 3 unidades
  bool get isLowStock => quantity <= 2;

  /// Rotación: cuántas veces se vende al mes
  double get rotationRate {
    if (quantity == 0) return 0;
    return unitsSold / quantity;
  }

  /// Score de vendabilidad (0-100)
  /// Considera: rotación, margen, demanda reciente
  int get saleabilityScore {
    int score = 50; // Base

    // Bonificar por rotación (productos que se venden rápido)
    if (rotationRate > 2) {
      score += 25;
    } else if (rotationRate > 1) {
      score += 15;
    } else if (rotationRate > 0.5) {
      score += 5;
    }

    // Bonificar por margen
    if (marginPercent > 50) {
      score += 15;
    } else if (marginPercent > 30) {
      score += 8;
    }
    // Penalizar stock bajo
    if (isLowStock) score -= 10;

    return score.clamp(0, 100);
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map, {int unitsSold = 0}) {
    final sellPrice = (map['price'] as num?)?.toDouble() ?? 0.0;
    final costPrice =
        (map['cost_price'] ?? map['costPrice'] as num?)?.toDouble() ?? 0.0;
    final quantity = (map['stock'] as num?)?.toInt() ?? 0;

    return InventoryItem(
      productId: (map['product_id'] as num).toInt(),
      name: map['name'] as String,
      sku: map['sku'] as String,
      category: map['category'] as String? ?? 'Sin categoría',
      sellPrice: sellPrice,
      costPrice: costPrice,
      quantity: quantity,
      unitsSold: unitsSold,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'name': name,
      'sku': sku,
      'category': category,
      'sell_price': sellPrice,
      'cost_price': costPrice,
      'quantity': quantity,
      'units_sold': unitsSold,
      'investment_value': investmentValue,
      'potential_gain': potentialGain,
    };
  }

  @override
  String toString() =>
      'InventoryItem(name: $name, qty: $quantity, inv: \$${investmentValue.toStringAsFixed(2)})';
}

/// Resumen de inversión en bodega
class InventorySummary {
  final double totalInvested; // Total invertido
  final double totalPotentialGain; // Ganancia potencial si se vende todo
  final int totalProducts; // Cantidad de productos diferentes
  final int totalUnits; // Total de unidades
  final int lowStockCount; // Productos con stock bajo
  final List<InventoryItem> topSellers; // Top 5 productos más vendidos
  final List<InventoryItem> topMargin; // Top 5 productos mayor margen
  final double averageMarginPercent;
  final double averageRotation;

  InventorySummary({
    required this.totalInvested,
    required this.totalPotentialGain,
    required this.totalProducts,
    required this.totalUnits,
    required this.lowStockCount,
    required this.topSellers,
    required this.topMargin,
    required this.averageMarginPercent,
    required this.averageRotation,
  });

  /// ROI potencial si se vende todo el stock actual
  double get potentialROI {
    if (totalInvested == 0) return 0;
    return (totalPotentialGain / totalInvested) * 100;
  }

  /// Valor promedio por producto
  double get averageProductValue {
    if (totalProducts == 0) return 0;
    return totalInvested / totalProducts;
  }
}
