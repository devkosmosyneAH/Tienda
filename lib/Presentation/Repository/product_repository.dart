import 'package:tienda/Presentation/Services/database_service.dart';

abstract class ProductRepository {
  Future<List<Map<String, dynamic>>> getStores();

  Future<List<Map<String, dynamic>>> getCategories();

  Future<List<Map<String, dynamic>>> getProducts({
    String search = '',
    int? storeId,
    String? category,
  });

  Future<int> createProduct({
    required String name,
    double price = 0,
    double costPrice = 0,
    double ivaRate = 0,
    String purchaseVatType = 'standard',
    double profitIva = 0,
    String? sku,
    String? auxCode,
    String? description,
    String? tags,
    int? storeId,
    String? categoryName,
    List<String> images = const [],
    Map<int, int> initialStock = const {},
  });

  Future<void> updateProduct({
    required int productId,
    required String name,
    required String categoryName,
    required String sku,
    required double price,
    double costPrice = 0,
    double ivaRate = 0,
    double profitIva = 0,
    String? auxCode,
    String? description,
    String? tags,
    int? storeId,
    List<String>? images,
  });

  Future<void> updateProductImages({
    required int productId,
    required List<String> imageIds,
  });

  Future<List<String>> getProductImageIds(int productId);

  Future<void> deleteProduct(int productId);

  Future<void> updateInventoryStock({
    required int productId,
    required int storeId,
    required int stock,
  });
}

class DatabaseProductRepository implements ProductRepository {
  const DatabaseProductRepository();

  @override
  Future<List<Map<String, dynamic>>> getStores() {
    return DatabaseService.getStores();
  }

  @override
  Future<List<Map<String, dynamic>>> getCategories() {
    return DatabaseService.getCategories();
  }

  @override
  Future<List<Map<String, dynamic>>> getProducts({
    String search = '',
    int? storeId,
    String? category,
  }) {
    return DatabaseService.getProducts(
      search: search,
      storeId: storeId,
      category: category,
    );
  }

  @override
  Future<int> createProduct({
    required String name,
    double price = 0,
    double costPrice = 0,
    double ivaRate = 0,
    String purchaseVatType = 'standard',
    double profitIva = 0,
    String? sku,
    String? auxCode,
    String? description,
    String? tags,
    int? storeId,
    String? categoryName,
    List<String> images = const [],
    Map<int, int> initialStock = const {},
  }) {
    return DatabaseService.createProduct(
      name: name,
      price: price,
      costPrice: costPrice,
      ivaRate: ivaRate,
      purchaseVatType: purchaseVatType,
      profitIva: profitIva,
      sku: sku,
      auxCode: auxCode,
      description: description,
      tags: tags,
      storeId: storeId,
      categoryName: categoryName,
      images: images,
      initialStock: initialStock,
    );
  }

  @override
  Future<void> updateProduct({
    required int productId,
    required String name,
    required String categoryName,
    required String sku,
    required double price,
    double costPrice = 0,
    double ivaRate = 0,
    double profitIva = 0,
    String? auxCode,
    String? description,
    String? tags,
    int? storeId,
    List<String>? images,
  }) {
    return DatabaseService.updateProduct(
      productId: productId,
      name: name,
      categoryName: categoryName,
      sku: sku,
      price: price,
      costPrice: costPrice,
      ivaRate: ivaRate,
      profitIva: profitIva,
      auxCode: auxCode,
      description: description,
      tags: tags,
      storeId: storeId,
      images: images,
    );
  }

  @override
  Future<void> updateProductImages({
    required int productId,
    required List<String> imageIds,
  }) {
    return DatabaseService.updateProductImages(
      productId: productId,
      imageIds: imageIds,
    );
  }

  @override
  Future<List<String>> getProductImageIds(int productId) {
    return DatabaseService.getProductImageIds(productId);
  }

  @override
  Future<void> deleteProduct(int productId) {
    return DatabaseService.deleteProduct(productId);
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
}
