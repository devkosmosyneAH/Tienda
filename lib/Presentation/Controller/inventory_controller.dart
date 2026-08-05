import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:flutter/foundation.dart';

class InventoryController extends ChangeNotifier {
  bool isLoading = false;
  String? errorMessage;
  String search = '';
  int? selectedStoreId;
  List<Map<String, dynamic>> stores = [];
  List<Map<String, dynamic>> inventory = [];

  int get totalProducts => inventory.length;

  int get totalUnits => inventory.fold<int>(
    0,
    (sum, item) => sum + ((item['stock'] as num?)?.toInt() ?? 0),
  );

  int get lowStockCount => inventory.where((item) {
    final stock = ((item['stock'] as num?)?.toInt() ?? 0);
    return stock <= 2;
  }).length;

  Future<void> initialize() async {
    if (isLoading || stores.isNotEmpty) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      stores = await DatabaseService.getStores();
      if (stores.isNotEmpty) {
        selectedStoreId ??= (stores.first['id'] as num).toInt();
        await loadInventory();
      }
    } catch (e) {
      errorMessage = 'No se pudo cargar el inventario: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectStore(int? storeId) async {
    if (storeId == null) return;
    selectedStoreId = storeId;
    await loadInventory();
  }

  Future<void> loadInventory() async {
    if (selectedStoreId == null) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      inventory = await DatabaseService.getInventoryByStore(
        selectedStoreId!,
        search: search,
      );
    } catch (e) {
      errorMessage = 'No se pudo actualizar el inventario: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSearch(String value) async {
    search = value;
    await loadInventory();
  }

  Future<void> updateStock({required int productId, required int stock}) async {
    if (selectedStoreId == null) return;
    await DatabaseService.updateInventoryStock(
      productId: productId,
      storeId: selectedStoreId!,
      stock: stock,
    );
    await loadInventory();
  }

  Future<void> transferStock({
    required int productId,
    required int fromStoreId,
    required int toStoreId,
    required int quantity,
  }) async {
    await DatabaseService.transferInventory(
      productId: productId,
      fromStoreId: fromStoreId,
      toStoreId: toStoreId,
      quantity: quantity,
    );
    await loadInventory();
  }
}
