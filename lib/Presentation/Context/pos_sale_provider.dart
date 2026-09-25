import 'package:tienda/Presentation/Model/pos_model.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────
//  PosSaleProvider — Estado de la venta activa en el POS
//  Gestiona: tipo comprobante, cliente, pagos, descuento, transporte
// ─────────────────────────────────────────────────────────────────

class PosSaleProvider extends ChangeNotifier {
  // ── Tipo de comprobante
  String _receiptType = PosReceiptType.notaVenta;
  String get receiptType => _receiptType;

  // ── Consumidor final / cliente seleccionado
  bool _isConsumerFinal = false;
  bool get isConsumerFinal => _isConsumerFinal;

  // ── Método de pago seleccionado (para agregar un nuevo pago)
  int? _selectedPaymentMethodId;
  int? get selectedPaymentMethodId => _selectedPaymentMethodId;

  // ── Lista de pagos registrados en esta venta
  final List<PosPaymentEntry> _payments = [];
  List<PosPaymentEntry> get payments => List.unmodifiable(_payments);

  // ── Descuento y transporte
  double _discount = 0;
  double get discount => _discount;

  double _transport = 0;
  double get transport => _transport;

  // ── Controladores de texto (para los campos de monto)
  final TextEditingController discountController = TextEditingController(
    text: '0',
  );
  final TextEditingController transportController = TextEditingController(
    text: '0',
  );
  final TextEditingController receivedController = TextEditingController(
    text: '0',
  );

  // ── Derivados
  double effectiveTotal(double subtotal) =>
      (subtotal - _discount + _transport).clamp(0, double.infinity);

  double get paymentsTotal => _payments.fold(0, (s, p) => s + p.amount);

  double receivedAmount() => double.tryParse(receivedController.text) ?? 0;

  double change(double subtotal) => receivedAmount() - effectiveTotal(subtotal);

  // ────────────────────────────────────────────────────────────────
  //  Mutaciones
  // ────────────────────────────────────────────────────────────────

  void setReceiptType(String value) {
    _receiptType = value;
    notifyListeners();
  }

  void setConsumerFinal(bool value) {
    _isConsumerFinal = value;
    notifyListeners();
  }

  void setDiscount(String raw) {
    _discount = double.tryParse(raw) ?? 0;
    notifyListeners();
  }

  void setTransport(String raw) {
    _transport = double.tryParse(raw) ?? 0;
    notifyListeners();
  }

  void selectPaymentMethod(int id) {
    _selectedPaymentMethodId = id;
    notifyListeners();
  }

  /// Agrega un pago por el monto restante con el método seleccionado.
  void addPayment(
    List<Map<String, dynamic>> methods,
    double total, {
    double? amount,
  }) {
    if (methods.isEmpty) return;
    final alreadyReceived = paymentsTotal;
    final remaining = total - alreadyReceived;
    final paymentAmount = amount ?? remaining;
    if (paymentAmount <= 0 || remaining <= 0) return;

    final methodId =
        _selectedPaymentMethodId ?? (methods.first['id'] as num).toInt();
    final method = methods.firstWhere(
      (m) => (m['id'] as num).toInt() == methodId,
      orElse: () => methods.first,
    );
    _payments.add(
      PosPaymentEntry(
        methodId: methodId,
        methodName: method['name'].toString(),
        amount: paymentAmount > remaining ? remaining : paymentAmount,
      ),
    );
    notifyListeners();
  }

  void removePayment(int index) {
    _payments.removeAt(index);
    notifyListeners();
  }

  /// Notifica un cambio en el campo "Recibido" (para recalcular cambio).
  void onReceivedChanged(String _) {
    notifyListeners();
  }

  /// Resetea toda la venta al estado inicial.
  void clearSale() {
    _payments.clear();
    _discount = 0;
    _transport = 0;
    _isConsumerFinal = false;
    _selectedPaymentMethodId = null;
    discountController.text = '0';
    transportController.text = '0';
    receivedController.text = '0';
    notifyListeners();
  }

  /// Construye la lista de pagos lista para enviar al checkout.
  List<Map<String, dynamic>> buildPayloads({
    required List<Map<String, dynamic>> paymentMethods,
    required double total,
  }) {
    if (_payments.isNotEmpty) {
      return _payments.map((p) => p.toMap()).toList();
    }
    // Pago único con el método seleccionado
    final methodId =
        _selectedPaymentMethodId ??
        (paymentMethods.isNotEmpty
            ? (paymentMethods.first['id'] as num).toInt()
            : 1);
    final String methodName = paymentMethods.isNotEmpty
        ? paymentMethods
              .firstWhere(
                (m) => (m['id'] as num).toInt() == methodId,
                orElse: () => paymentMethods.first,
              )['name']
              .toString()
        : 'Efectivo';
    return [
      {'method_id': methodId, 'method_name': methodName, 'amount': total},
    ];
  }

  @override
  void dispose() {
    discountController.dispose();
    transportController.dispose();
    receivedController.dispose();
    super.dispose();
  }
}
