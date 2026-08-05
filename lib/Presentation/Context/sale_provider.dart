import 'package:flutter/foundation.dart';
import 'package:tienda/Presentation/Model/sale_model.dart';
import 'package:tienda/Presentation/Services/database_service.dart';

class SaleProvider extends ChangeNotifier {
  SaleProvider() {
    DatabaseService.addDatabaseListener(_handleDatabaseChanged);
  }

  bool isLoading = false;
  String? errorMessage;

  List<Sale> sales = [];
  Sale? currentSale;
  List<SaleItem> cartItems = [];

  int? selectedStoreId;
  int? selectedCustomerId;
  DateTime? selectedDate;

  void _handleDatabaseChanged() {
    if (!isLoading) {
      loadSales();
    }
  }

  @override
  void dispose() {
    DatabaseService.removeDatabaseListener(_handleDatabaseChanged);
    super.dispose();
  }

  Future<void> initialize() async {
    if (isLoading || sales.isNotEmpty) return;
    await loadSales();
  }

  Future<void> loadSales({DateTime? fromDate, DateTime? toDate}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final rawSales = await DatabaseService.getSalesHistory(
        year: fromDate?.year,
        month: fromDate?.month,
        day: fromDate?.day,
      );

      sales = rawSales.map((s) {
        return Sale(
          id: (s['id'] as num).toInt(),
          customerId: 0,
          customerName: s['client_name'] as String,
          storeId: 0,
          items: [],
          subtotal: 0,
          discount: 0.0,
          tax: 0.0,
          total: (s['total'] as num).toDouble(),
          paymentMethod: PaymentMethod.cash,
          status: SaleStatus.completed,
          saleDate: DateTime.parse(s['date'] as String),
          createdAt: DateTime.parse(s['date'] as String),
        );
      }).toList();

      if (fromDate != null && toDate != null) {
        sales = sales
            .where(
              (s) =>
                  s.saleDate.isAfter(fromDate) && s.saleDate.isBefore(toDate),
            )
            .toList();
      }

      sales.sort((a, b) => b.saleDate.compareTo(a.saleDate));
    } catch (e) {
      errorMessage = 'Error al cargar ventas: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Añade un producto al carrito
  void addToCart(
    int productId,
    String productName,
    int quantity,
    double unitPrice, {
    double discount = 0.0,
  }) {
    final existingIndex = cartItems.indexWhere(
      (item) => item.productId == productId,
    );

    if (existingIndex >= 0) {
      // Producto ya existe, aumentar cantidad
      final existingItem = cartItems[existingIndex];
      cartItems[existingIndex] = SaleItem(
        productId: existingItem.productId,
        productName: existingItem.productName,
        quantity: existingItem.quantity + quantity,
        unitPrice: existingItem.unitPrice,
        discount: discount,
        totalPrice:
            (existingItem.unitPrice * (existingItem.quantity + quantity)) -
            (discount * (existingItem.quantity + quantity)),
      );
    } else {
      // Nuevo producto
      cartItems.add(
        SaleItem(
          productId: productId,
          productName: productName,
          quantity: quantity,
          unitPrice: unitPrice,
          discount: discount,
          totalPrice: (unitPrice * quantity) - (discount * quantity),
        ),
      );
    }

    notifyListeners();
  }

  /// Elimina un producto del carrito
  void removeFromCart(int productId) {
    cartItems.removeWhere((item) => item.productId == productId);
    notifyListeners();
  }

  /// Actualiza la cantidad de un producto
  void updateCartItemQuantity(int productId, int newQuantity) {
    final index = cartItems.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      final item = cartItems[index];
      if (newQuantity <= 0) {
        removeFromCart(productId);
      } else {
        cartItems[index] = SaleItem(
          productId: item.productId,
          productName: item.productName,
          quantity: newQuantity,
          unitPrice: item.unitPrice,
          discount: item.discount,
          totalPrice:
              (item.unitPrice * newQuantity) - (item.discount * newQuantity),
        );
        notifyListeners();
      }
    }
  }

  /// Limpia el carrito
  void clearCart() {
    cartItems.clear();
    selectedCustomerId = null;
    notifyListeners();
  }

  /// Procesa una venta
  /// 🔄 NOTA: Requiere implementar el método createSale en DatabaseService
  Future<void> processSale({
    required int customerId,
    required int storeId,
    required PaymentMethod paymentMethod,
    String? paymentReference,
    double discount = 0.0,
    double tax = 0.0,
    String? notes,
  }) async {
    if (cartItems.isEmpty) {
      errorMessage = 'El carrito está vacío';
      notifyListeners();
      return;
    }

    try {
      isLoading = true;
      notifyListeners();

      // final subtotal =
      //     cartItems.fold<double>(0, (sum, item) => sum + item.subtotal);
      // final total = subtotal - discount + tax;

      // Crear la venta
      // final sale = Sale(
      //   id: 0,
      //   customerId: customerId,
      //   customerName: '', // Obtener del servicio
      //   storeId: storeId,
      //   items: cartItems,
      //   subtotal: subtotal,
      //   discount: discount,
      //   tax: tax,
      //   total: total,
      //   paymentMethod: paymentMethod,
      //   paymentReference: paymentReference,
      //   notes: notes,
      //   status: SaleStatus.completed,
      //   saleDate: DateTime.now(),
      //   createdAt: DateTime.now(),
      // );

      //
      // await DatabaseService.createSale(sale.toMap());

      clearCart();
      await loadSales();

      errorMessage = null;
    } catch (e) {
      errorMessage = 'Error al procesar venta: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Calcula el total del carrito
  double get cartTotal =>
      cartItems.fold<double>(0, (sum, item) => sum + item.totalPrice);

  /// Cantidad total de items
  int get cartItemCount =>
      cartItems.fold<int>(0, (sum, item) => sum + item.quantity);

  /// Calcula el subtotal
  double get cartSubtotal => cartItems.fold<double>(
    0,
    (sum, item) => sum + (item.unitPrice * item.quantity),
  );

  /// Total de ventas
  double get totalSales =>
      sales.fold<double>(0, (sum, sale) => sum + sale.total);

  /// Ventas del día
  List<Sale> get todaySales {
    final now = DateTime.now();
    return sales
        .where(
          (s) =>
              s.saleDate.year == now.year &&
              s.saleDate.month == now.month &&
              s.saleDate.day == now.day,
        )
        .toList();
  }

  /// Total de ventas del día
  double get todayTotal =>
      todaySales.fold<double>(0, (sum, sale) => sum + sale.total);

  /// Agrupar ventas por método de pago
  Map<PaymentMethod, double> get salesByPaymentMethod {
    final result = <PaymentMethod, double>{};
    for (var sale in sales) {
      final current = result[sale.paymentMethod] ?? 0;
      result[sale.paymentMethod] = current + sale.total;
    }
    return result;
  }
}
