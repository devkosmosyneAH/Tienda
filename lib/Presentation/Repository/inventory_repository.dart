import 'package:tienda/Presentation/Services/database_service.dart';

abstract class InventoryRepository {
  Future<List<Map<String, dynamic>>> getStores();

  Future<List<Map<String, dynamic>>> getInventoryByStore(
    int storeId, {
    String search = '',
  });

  Future<Map<String, dynamic>?> getInventoryStock({
    required int productId,
    required int storeId,
  });

  Future<void> updateInventoryStock({
    required int productId,
    required int storeId,
    required int stock,
  });

  Future<void> transferInventory({
    required int productId,
    required int fromStoreId,
    required int toStoreId,
    required int quantity,
  });
}

class DatabaseInventoryRepository implements InventoryRepository {
  const DatabaseInventoryRepository();

  @override
  Future<List<Map<String, dynamic>>> getStores() {
    return DatabaseService.getStores();
  }

  @override
  Future<List<Map<String, dynamic>>> getInventoryByStore(
    int storeId, {
    String search = '',
  }) {
    return DatabaseService.getInventoryByStore(storeId, search: search);
  }

  @override
  Future<Map<String, dynamic>?> getInventoryStock({
    required int productId,
    required int storeId,
  }) async {
    final rows = await DatabaseService.rawQuery(
      'SELECT stock FROM inventory WHERE product_id = ? AND store_id = ? LIMIT 1',
      [productId, storeId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<void> updateInventoryStock({
    required int productId,
    required int storeId,
    required int stock,
  }) {
    return DatabaseService.updateInventoryStock(
      productId: productId,
      storeId: storeId,
      stock: stock,
    );
  }

  @override
  Future<void> transferInventory({
    required int productId,
    required int fromStoreId,
    required int toStoreId,
    required int quantity,
  }) {
    return DatabaseService.transferInventory(
      productId: productId,
      fromStoreId: fromStoreId,
      toStoreId: toStoreId,
      quantity: quantity,
    );
  }
}
