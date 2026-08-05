// ─────────────────────────────────────────────────────────────────
//  POS Model — Modelos de datos del sistema de ventas
// ─────────────────────────────────────────────────────────────────

/// Tipos de comprobante disponibles en el POS
class PosReceiptType {
  static const String notaVenta = 'Nota de Venta';
  static const String factura = 'Factura';
  static const String recibo = 'Recibo';

  static const List<String> all = [notaVenta, factura, recibo];
}

/// Entrada de pago en una venta (puede haber varios métodos)
class PosPaymentEntry {
  final int methodId;
  final String methodName;
  final double amount;

  const PosPaymentEntry({
    required this.methodId,
    required this.methodName,
    required this.amount,
  });

  Map<String, dynamic> toMap() => {
    'method_id': methodId,
    'method_name': methodName,
    'amount': amount,
  };

  @override
  String toString() => 'PosPaymentEntry($methodName: \$$amount)';
}

/// Ítem en el carrito de compra
class PosCartItem {
  final int productId;
  final String name;
  final double price;
  final int stock;
  int quantity;

  PosCartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.stock,
    this.quantity = 1,
  });

  double get subtotal => price * quantity;

  Map<String, dynamic> toMap() => {
    'product_id': productId,
    'name': name,
    'price': price,
    'quantity': quantity,
    'stock': stock,
  };

  factory PosCartItem.fromMap(Map<String, dynamic> map) => PosCartItem(
    productId: (map['product_id'] as num).toInt(),
    name: map['name'].toString(),
    price: (map['price'] as num).toDouble(),
    stock: ((map['stock'] as num?)?.toInt()) ?? 0,
    quantity: ((map['quantity'] as num?)?.toInt()) ?? 1,
  );
}
