import 'package:tienda/Presentation/Context/pos_sale_provider.dart';
import 'package:tienda/Presentation/Controller/pos_controller.dart';
import 'package:tienda/Presentation/Model/pos_model.dart';

// ─────────────────────────────────────────────────────────────────
//  UsePosSale — Hook de utilidades para el sistema de ventas POS
//  Contiene lógica de cálculo y construcción de payloads.
// ─────────────────────────────────────────────────────────────────

class UsePosSale {
  /// Calcula el total efectivo aplicando descuento y transporte.
  static double effectiveTotal({
    required double subtotal,
    required double discount,
    required double transport,
  }) => (subtotal - discount + transport).clamp(0, double.infinity);

  /// Calcula el cambio a devolver al cliente.
  static double change({
    required double received,
    required double total,
  }) => received - total;

  /// Determina si hay saldo pendiente por pagar.
  static bool hasPendingBalance({
    required double total,
    required double paymentsTotal,
  }) => paymentsTotal < total - 0.01;

  /// Construye la lista de pagos para el checkout.
  /// Usa los pagos múltiples si existen; de lo contrario, un único pago.
  static List<Map<String, dynamic>> buildCheckoutPayments({
    required PosSaleProvider saleProvider,
    required PosController posController,
    required double total,
  }) {
    return saleProvider.buildPayloads(
      paymentMethods: posController.paymentMethods,
      total: total,
    );
  }

  /// Parsea un texto de monto de forma segura.
  static double parseAmount(String text) => double.tryParse(text) ?? 0;

  /// Formatea un double como precio en dólares.
  static String formatPrice(double amount) => '\$${amount.toStringAsFixed(2)}';

  /// Devuelve el nombre de un método de pago por su id.
  static String resolveMethodName({
    required List<Map<String, dynamic>> methods,
    required int? selectedId,
  }) {
    if (methods.isEmpty) return 'Efectivo';
    final id = selectedId ?? (methods.first['id'] as num).toInt();
    final method = methods.firstWhere(
      (m) => (m['id'] as num).toInt() == id,
      orElse: () => methods.first,
    );
    return method['name'].toString();
  }

  /// Convierte un Map del carrito a PosCartItem.
  static PosCartItem cartItemFromMap(Map<String, dynamic> map) =>
      PosCartItem.fromMap(map);
}
