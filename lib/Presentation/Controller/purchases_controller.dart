import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:tienda/Presentation/Services/audit_service.dart';

enum PurchaseHistoryPeriod { all, today, week, month }

class PurchasesController extends ChangeNotifier {
  bool isLoading = false;
  bool isHistoryLoading = false;
  String? errorMessage;

  int? selectedStoreId;
  int? selectedSupplierId;
  int? historySupplierId;
  String? historyCategory;
  DateTime? historyDate;
  DateTime? historyFromDate;
  DateTime? historyToDate;
  String historySearch = '';
  PurchaseHistoryPeriod historyPeriod = PurchaseHistoryPeriod.all;
  String search = '';

  List<Map<String, dynamic>> stores = [];
  List<Map<String, dynamic>> suppliers = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> cart = [];
  List<Map<String, dynamic>> purchaseHistory = [];
  List<Map<String, dynamic>> paymentMethods = [];
  int _historyRequestSequence = 0;

  String invoiceNumber = '';
  String auxiliaryInvoiceNumber = '';
  int? selectedPaymentMethodId;
  String selectedPaymentMethodName = 'Contado';

  bool considerVatProfit = false;
  double governmentVatRate = 15.0;
  double profitVatRate = 15.0;
  double discount = 0;

  double get subtotal => cart.fold<double>(
    0,
    (sum, item) => sum + ((item['quantity'] as int) * (item['cost'] as double)),
  );

  double get appliedVatRate => governmentVatRate;

  double get vatTotal => subtotal * appliedVatRate / 100;

  double get total =>
      (subtotal + vatTotal - discount).clamp(0, double.infinity);

  int get productsWithVat => governmentVatRate > 0 ? cart.length : 0;

  int get historyTotalCount => purchaseHistory.length;

  int get historyPaidCount => purchaseHistory.where((purchase) {
    final payment = purchase['payment_method']?.toString().toLowerCase() ?? '';
    return !payment.contains('crédito') && !payment.contains('credito');
  }).length;

  int get historyPendingCount => historyTotalCount - historyPaidCount;

  double get historyTotalAmount => purchaseHistory.fold<double>(
    0,
    (sum, purchase) => sum + ((purchase['total'] as num?)?.toDouble() ?? 0),
  );

  void setConsiderVatProfit(bool value) {
    considerVatProfit = value;
    notifyListeners();
  }

  void updateGovernmentVatRate(double value) {
    governmentVatRate = value < 0 ? 0 : value;
    notifyListeners();
  }

  void updateProfitVatRate(double value) {
    profitVatRate = value < 0 ? 0 : value;
    notifyListeners();
  }

  void updateDiscount(double value) {
    discount = value < 0 ? 0 : value;
    notifyListeners();
  }

  void updateAuxiliaryInvoiceNumber(String value) {
    auxiliaryInvoiceNumber = value;
    notifyListeners();
  }

  void selectPaymentMethod(int? methodId) {
    if (methodId == null) return;
    selectedPaymentMethodId = methodId;
    final method = paymentMethods.firstWhere(
      (item) => (item['id'] as num).toInt() == methodId,
      orElse: () => <String, dynamic>{},
    );
    selectedPaymentMethodName = _paymentMethodLabel(
      method['name']?.toString() ?? 'Contado',
    );
    notifyListeners();
  }

  String _paymentMethodLabel(String name) {
    return name.toLowerCase() == 'efectivo' ? 'Contado' : name;
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
      suppliers = await DatabaseService.getSuppliers();
      categories = await DatabaseService.getCategories();
      paymentMethods = await DatabaseService.getPaymentMethods();
      selectedPaymentMethodId ??= paymentMethods.isNotEmpty
          ? (paymentMethods.first['id'] as num).toInt()
          : null;
      selectedPaymentMethodName = paymentMethods.isNotEmpty
          ? _paymentMethodLabel(paymentMethods.first['name'].toString())
          : 'Contado';
      invoiceNumber = await DatabaseService.getNextPurchaseInvoiceNumber();
      if (stores.isNotEmpty) {
        selectedStoreId ??= (stores.first['id'] as num).toInt();
      }
      await _loadProducts();
      await loadPurchaseHistory();
    } catch (e) {
      errorMessage = 'No se pudo cargar el módulo de compras: $e';
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
    await loadPurchaseHistory();
  }

  void selectSupplier(int? supplierId) {
    selectedSupplierId = supplierId;
    notifyListeners();
  }

  Future<Map<String, dynamic>> createSupplier({
    required String name,
    String? phone,
    String? email,
    String? notes,
    String? ruc,
  }) async {
    final supplierId = await DatabaseService.createSupplier(
      name: name,
      phone: phone,
      email: email,
      notes: notes,
      ruc: ruc,
    );
    await AuditService.log(
      action: AuditAction.createSupplier,
      module: 'Suppliers',
      page: 'PurchasesView',
      entity: 'supplier',
      entityId: supplierId,
      newData: {
        'name': name.trim(),
        'phone': phone?.trim(),
        'email': email?.trim(),
        'ruc': ruc?.trim(),
      },
      controller: 'PurchasesController',
    );
    DatabaseService.notifyDatabaseChanged();
    suppliers = await DatabaseService.getSuppliers();
    selectedSupplierId = supplierId;
    notifyListeners();
    return suppliers.firstWhere(
      (supplier) => (supplier['id'] as num).toInt() == supplierId,
    );
  }

  Future<void> updateSearch(String value) async {
    search = value;
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (selectedStoreId == null) {
      products = [];
      notifyListeners();
      return;
    }

    products = await DatabaseService.getProducts(
      search: search,
      storeId: selectedStoreId,
    );
    notifyListeners();
  }

  void addToCart(Map<String, dynamic> product) {
    final productId = (product['id'] as num).toInt();
    final index = cart.indexWhere((item) => item['product_id'] == productId);

    if (index >= 0) {
      cart[index]['quantity'] = (cart[index]['quantity'] as int) + 1;
    } else {
      cart.add({
        'product_id': productId,
        'name': product['name'],
        'quantity': 1,
        'cost':
            ((product['cost_price'] ?? product['cost']) as num?)?.toDouble() ??
            0,
      });
    }

    notifyListeners();
  }

  void incrementQuantity(int productId) {
    final index = cart.indexWhere((item) => item['product_id'] == productId);
    if (index < 0) return;
    cart[index]['quantity'] = (cart[index]['quantity'] as int) + 1;
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

  void removeFromCart(int productId) {
    cart.removeWhere((item) => item['product_id'] == productId);
    notifyListeners();
  }

  void updateCost(int productId, double cost) {
    final index = cart.indexWhere((item) => item['product_id'] == productId);
    if (index < 0) return;
    cart[index]['cost'] = cost < 0 ? 0 : cost;
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
  }

  Future<int> savePurchase({
    String? supplierName,
    String? supplierPhone,
  }) async {
    if (selectedStoreId == null) {
      throw Exception('Selecciona el local donde ingresará el stock');
    }
    if (cart.isEmpty) {
      throw Exception('Agrega productos a la compra');
    }

    final purchaseId = await DatabaseService.registerPurchase(
      storeId: selectedStoreId!,
      supplierId: selectedSupplierId,
      supplierName: supplierName,
      supplierPhone: supplierPhone,
      vatRate: appliedVatRate,
      discount: discount,
      invoiceNumber: invoiceNumber,
      auxiliaryInvoiceNumber: auxiliaryInvoiceNumber,
      paymentMethod: selectedPaymentMethodName,
      items: cart
          .map(
            (item) => {
              'product_id': item['product_id'],
              'quantity': item['quantity'],
              'cost': item['cost'],
            },
          )
          .toList(),
    );

    final supplierNameForAudit = suppliers
        .where(
          (supplier) => (supplier['id'] as num).toInt() == selectedSupplierId,
        )
        .map((supplier) => supplier['name']?.toString())
        .firstOrNull;
    await AuditService.log(
      action: AuditAction.createPurchase,
      module: 'Purchases',
      page: 'PurchasesView',
      entity: 'purchase',
      entityId: purchaseId,
      newData: {
        'purchase_id': purchaseId,
        'products': cart,
        'supplier': supplierNameForAudit ?? supplierName,
        'supplier_id': selectedSupplierId,
        'payment_method': selectedPaymentMethodName,
      },
      controller: 'PurchasesController',
    );

    cart.clear();
    selectedSupplierId = null;
    invoiceNumber = await DatabaseService.getNextPurchaseInvoiceNumber();
    auxiliaryInvoiceNumber = '';
    DatabaseService.notifyDatabaseChanged();
    suppliers = await DatabaseService.getSuppliers();
    await _loadProducts();
    await loadPurchaseHistory();
    return purchaseId;
  }

  Future<void> selectHistorySupplier(int? supplierId) async {
    historySupplierId = supplierId;
    await loadPurchaseHistory();
  }

  Future<void> selectHistoryPeriod(PurchaseHistoryPeriod period) async {
    historyPeriod = period;
    historyDate = null;
    historyFromDate = null;
    historyToDate = null;
    await loadPurchaseHistory();
  }

  Future<void> selectHistoryCategory(String? category) async {
    historyCategory = category;
    await loadPurchaseHistory();
  }

  Future<void> setHistoryDate(DateTime? value) async {
    historyDate = value;
    historyPeriod = PurchaseHistoryPeriod.all;
    historyFromDate = null;
    historyToDate = null;
    await loadPurchaseHistory();
  }

  Future<void> setHistoryDateRange({DateTime? from, DateTime? to}) async {
    if (from != null && to != null && to.isBefore(from)) {
      throw ArgumentError(
        'La fecha final debe ser igual o posterior a la inicial.',
      );
    }
    historyDate = null;
    historyPeriod = PurchaseHistoryPeriod.all;
    historyFromDate = from;
    historyToDate = to;
    await loadPurchaseHistory();
  }

  Future<void> updateHistorySearch(String value) async {
    historySearch = value;
    await loadPurchaseHistory();
  }

  Future<void> clearHistoryFilters() async {
    historySupplierId = null;
    historyCategory = null;
    historyDate = null;
    historyFromDate = null;
    historyToDate = null;
    historySearch = '';
    historyPeriod = PurchaseHistoryPeriod.all;
    await loadPurchaseHistory();
  }

  Future<void> loadPurchaseHistory() async {
    final requestSequence = ++_historyRequestSequence;
    isHistoryLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      DateTime? fromDate;
      DateTime? toDate;
      switch (historyPeriod) {
        case PurchaseHistoryPeriod.all:
          break;
        case PurchaseHistoryPeriod.today:
          fromDate = DateTime(now.year, now.month, now.day);
          toDate = fromDate.add(const Duration(days: 1));
        case PurchaseHistoryPeriod.week:
          final dayStart = DateTime(now.year, now.month, now.day);
          fromDate = dayStart.subtract(Duration(days: dayStart.weekday - 1));
          toDate = fromDate.add(const Duration(days: 7));
        case PurchaseHistoryPeriod.month:
          fromDate = DateTime(now.year, now.month);
          toDate = DateTime(now.year, now.month + 1);
      }
      if (historyFromDate != null) {
        fromDate = DateTime(
          historyFromDate!.year,
          historyFromDate!.month,
          historyFromDate!.day,
        );
      }
      if (historyToDate != null) {
        toDate = DateTime(
          historyToDate!.year,
          historyToDate!.month,
          historyToDate!.day + 1,
        );
      }
      final results = await DatabaseService.getPurchaseHistory(
        storeId: selectedStoreId,
        supplierId: historySupplierId,
        category: historyCategory,
        date: historyDate,
        fromDate: fromDate,
        toDate: toDate,
        search: historySearch,
      );
      if (requestSequence != _historyRequestSequence) return;
      purchaseHistory = results;
      errorMessage = null;
    } catch (e) {
      if (requestSequence == _historyRequestSequence) {
        errorMessage = 'No se pudo cargar el historial de compras: $e';
      }
    } finally {
      if (requestSequence == _historyRequestSequence) {
        isHistoryLoading = false;
        notifyListeners();
      }
    }
  }

  Future<List<Map<String, dynamic>>> getPurchaseItems(int purchaseId) {
    return DatabaseService.getPurchaseItems(purchaseId);
  }
}
