import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:tienda/Presentation/Services/audit_service.dart';

class PosController extends ChangeNotifier {
  PosController() {
    DatabaseService.addDatabaseListener(_handleDatabaseChanged);
  }

  bool isLoading = false;
  String? errorMessage;
  int? selectedStoreId;
  int? selectedCustomerId;
  int? historyCustomerId;
  String search = '';
  DateTime? historyDate;
  int? historyYear;
  int? historyMonth;
  int? historyDay;
  int totalSalesCount = 0;

  List<Map<String, dynamic>> stores = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> paymentMethods = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> cart = [];
  List<Map<String, dynamic>> salesHistory = [];

  double get total => cart.fold<double>(
    0,
    (sum, item) =>
        sum + ((item['quantity'] as int) * (item['price'] as double)),
  );

  int get totalItems =>
      cart.fold<int>(0, (sum, item) => sum + (item['quantity'] as int));

  void _handleDatabaseChanged() {
    if (!isLoading) {
      refresh();
    }
  }

  @override
  void dispose() {
    DatabaseService.removeDatabaseListener(_handleDatabaseChanged);
    super.dispose();
  }

  Future<void> initialize() async {
    if (isLoading || stores.isNotEmpty) return;
    await refresh();
  }

  Future<void> refresh() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      stores = await DatabaseService.getStores();
      customers = await DatabaseService.getCustomers();
      paymentMethods = await DatabaseService.getPaymentMethods();
      if (stores.isNotEmpty) {
        selectedStoreId ??= (stores.first['id'] as num).toInt();
      }
      await _loadProducts();
      await loadSalesHistory();
    } catch (e) {
      errorMessage = 'No se pudo cargar el POS: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectStore(int? storeId) async {
    if (storeId == null) return;
    selectedStoreId = storeId;
    cart.clear();
    await _loadProducts();
    await loadSalesHistory();
  }

  Future<void> updateSearch(String value) async {
    search = value;
    await _loadProducts();
  }

  Future<void> reloadCustomers() async {
    customers = await DatabaseService.getCustomers();
    notifyListeners();
  }

  void selectCustomer(int? customerId) {
    selectedCustomerId = customerId;
    notifyListeners();
  }

  Future<void> updateCustomer({
    required int id,
    required String name,
    String? phone,
    String? email,
    String? notes,
    String? cedula,
    String? identificationType,
    String? address,
  }) async {
    await DatabaseService.updateCustomer(
      id: id,
      name: name,
      phone: phone,
      email: email,
      notes: notes,
      cedula: cedula,
      identificationType: identificationType,
      address: address,
    );
    customers = await DatabaseService.getCustomers();
    notifyListeners();
  }

  Future<void> selectHistoryCustomer(int? customerId) async {
    historyCustomerId = customerId;
    await loadSalesHistory();
  }

  Future<void> setHistoryYear(int? year) async {
    historyYear = year;
    historyMonth = null;
    historyDay = null;
    await loadSalesHistory();
  }

  Future<void> setHistoryMonth(int? month) async {
    historyMonth = month;
    historyDay = null;
    await loadSalesHistory();
  }

  Future<void> setHistoryDay(int? day) async {
    historyDay = day;
    await loadSalesHistory();
  }

  Future<void> setHistoryDate(DateTime? value) async {
    historyDate = value;
    await loadSalesHistory();
  }

  Future<void> clearHistoryFilters() async {
    historyCustomerId = null;
    historyDate = null;
    historyYear = null;
    historyMonth = null;
    historyDay = null;
    await loadSalesHistory();
  }

  Future<void> loadSalesHistory() async {
    try {
      salesHistory = await DatabaseService.getSalesHistory(
        storeId: selectedStoreId,
        customerId: historyCustomerId,
        year: historyYear,
        month: historyMonth,
        day: historyDay,
      );
      totalSalesCount = await DatabaseService.getSalesHistoryCount(
        storeId: selectedStoreId,
        customerId: historyCustomerId,
        year: historyYear,
        month: historyMonth,
        day: historyDay,
      );
      errorMessage = null;
    } catch (e) {
      errorMessage = 'No se pudo cargar el historial de ventas: $e';
    }
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) {
    return DatabaseService.getSaleItems(saleId);
  }

  Future<void> _loadProducts() async {
    if (selectedStoreId == null) {
      products = [];
      notifyListeners();
      return;
    }

    try {
      products = await DatabaseService.getInventoryByStore(
        selectedStoreId!,
        search: search,
      );
      errorMessage = null;
    } catch (e) {
      errorMessage = 'No se pudo actualizar el catálogo de venta: $e';
    }

    notifyListeners();
  }

  void addToCart(Map<String, dynamic> product) {
    final productId = (product['product_id'] as num).toInt();
    final stock = ((product['stock'] as num?)?.toInt()) ?? 0;
    final index = cart.indexWhere(
      (item) => (item['product_id'] as int) == productId,
    );

    if (stock <= 0) {
      errorMessage = 'Este producto no tiene stock disponible en el local';
      notifyListeners();
      return;
    }

    if (index >= 0) {
      final currentQty = cart[index]['quantity'] as int;
      if (currentQty >= stock) {
        errorMessage = 'No puedes vender más del stock disponible';
        notifyListeners();
        return;
      }
      cart[index]['quantity'] = currentQty + 1;
    } else {
      cart.add({
        'product_id': productId,
        'name': product['name'],
        'price': ((product['price'] as num?)?.toDouble()) ?? 0,
        'quantity': 1,
        'stock': stock,
      });
    }

    errorMessage = null;
    notifyListeners();
  }

  void incrementQuantity(int productId) {
    final index = cart.indexWhere((item) => item['product_id'] == productId);
    if (index < 0) return;

    final stock = cart[index]['stock'] as int;
    final currentQty = cart[index]['quantity'] as int;
    if (currentQty < stock) {
      cart[index]['quantity'] = currentQty + 1;
      errorMessage = null;
    } else {
      errorMessage = 'Stock máximo alcanzado';
    }
    notifyListeners();
  }

  void decrementQuantity(int productId) {
    final index = cart.indexWhere((item) => item['product_id'] == productId);
    if (index < 0) return;

    final currentQty = cart[index]['quantity'] as int;
    if (currentQty <= 1) {
      cart.removeAt(index);
    } else {
      cart[index]['quantity'] = currentQty - 1;
    }
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
  }

  Future<int> checkout({
    List<Map<String, dynamic>>? payments,
    bool isCredit = false,
  }) async {
    if (selectedStoreId == null) {
      throw Exception('Selecciona un local antes de vender');
    }
    if (cart.isEmpty) {
      throw Exception('Agrega productos al carrito');
    }

    final activeSession = await DatabaseService.getActiveCashSession(
      selectedStoreId!,
    );

    if (activeSession == null) {
      throw Exception('Debes abrir caja en este local antes de vender');
    }

    final saleTotal = total;
    final normalizedPayments = (payments == null || payments.isEmpty)
        ? [
            {
              'method_id':
                  (paymentMethods.firstWhere(
                            (m) =>
                                (m['name'] ?? '').toString().toLowerCase() ==
                                'efectivo',
                            orElse: () => paymentMethods.first,
                          )['id']
                          as num)
                      .toInt(),
              'method_name': 'Efectivo',
              'amount': saleTotal,
            },
          ]
        : payments
              .where((p) => ((p['amount'] as num?)?.toDouble() ?? 0) > 0)
              .toList();

    final paidAmount = normalizedPayments.fold<double>(
      0,
      (sum, payment) => sum + ((payment['amount'] as num).toDouble()),
    );

    if (!isCredit && (paidAmount - saleTotal).abs() > 0.01) {
      throw Exception('Los pagos deben sumar exactamente el total');
    }

    if (isCredit && paidAmount - saleTotal > 0.01) {
      throw Exception('El abono no puede superar el total de la venta');
    }

    final saleId = await DatabaseService.registerSaleWithPayments(
      storeId: selectedStoreId!,
      clientId: selectedCustomerId,
      sessionId: (activeSession['id'] as num).toInt(),
      isCredit: isCredit,
      payments: normalizedPayments,
      items: cart
          .map(
            (item) => {
              'product_id': item['product_id'],
              'quantity': item['quantity'],
              'price': item['price'],
            },
          )
          .toList(),
    );

    await AuditService.log(
      action: AuditAction.createSale, module: 'POS', page: 'POSView',
      entity: 'sale', entityId: saleId,
      newData: {'sale_id': saleId, 'total': saleTotal, 'customer_id': selectedCustomerId,
        'products': cart, 'payment_method': normalizedPayments.map((p) => p['method_name']).toList()},
      controller: 'PosController',
    );

    cart.clear();
    await _loadProducts();
    await loadSalesHistory();
    return saleId;
  }
}
