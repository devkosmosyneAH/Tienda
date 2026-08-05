import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:flutter/foundation.dart';

class PurchasesController extends ChangeNotifier {
  bool isLoading = false;
  bool isHistoryLoading = false;
  String? errorMessage;

  int? selectedStoreId;
  int? historySupplierId;
  DateTime? historyDate;
  String search = '';

  List<Map<String, dynamic>> stores = [];
  List<Map<String, dynamic>> suppliers = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> cart = [];
  List<Map<String, dynamic>> purchaseHistory = [];

  double get total => cart.fold<double>(
    0,
    (sum, item) => sum + ((item['quantity'] as int) * (item['cost'] as double)),
  );

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

  Future<void> updateSearch(String value) async {
    search = value;
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    products = await DatabaseService.getProducts(search: search);
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
        'cost': ((product['price'] as num?)?.toDouble()) ?? 0,
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
      supplierName: supplierName,
      supplierPhone: supplierPhone,
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

    cart.clear();
    suppliers = await DatabaseService.getSuppliers();
    await _loadProducts();
    await loadPurchaseHistory();
    return purchaseId;
  }

  Future<void> selectHistorySupplier(int? supplierId) async {
    historySupplierId = supplierId;
    await loadPurchaseHistory();
  }

  Future<void> setHistoryDate(DateTime? value) async {
    historyDate = value;
    await loadPurchaseHistory();
  }

  Future<void> clearHistoryFilters() async {
    historySupplierId = null;
    historyDate = null;
    await loadPurchaseHistory();
  }

  Future<void> loadPurchaseHistory() async {
    isHistoryLoading = true;
    notifyListeners();

    try {
      purchaseHistory = await DatabaseService.getPurchaseHistory(
        storeId: selectedStoreId,
        supplierId: historySupplierId,
        date: historyDate,
      );
      errorMessage = null;
    } catch (e) {
      errorMessage = 'No se pudo cargar el historial de compras: $e';
    } finally {
      isHistoryLoading = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> getPurchaseItems(int purchaseId) {
    return DatabaseService.getPurchaseItems(purchaseId);
  }
}
