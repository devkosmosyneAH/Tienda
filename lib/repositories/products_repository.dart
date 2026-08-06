import 'package:tienda/api/api_client.dart';
import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:tienda/Presentation/Services/image_storage_service.dart';
import 'package:tienda/core/platform_runtime.dart';
import 'package:tienda/repositories/base_repository.dart';

class ProductsRepository extends BaseRepository<Map<String, dynamic>> {
  ProductsRepository({ApiClient? apiClient}) : super(apiClient ?? ApiClient());

  Future<List<Map<String, dynamic>>> getProducts({
    String search = '',
    int? storeId,
    String? category,
  }) async {
    if (!_usesLocalApi) {
      return DatabaseService.getProducts(
        search: search,
        storeId: storeId,
        category: category,
      );
    }
    final uri = '/api/products?search=${Uri.encodeComponent(search)}';
    final query = <String, String>{};
    if (storeId != null) query['storeId'] = storeId.toString();
    if (category != null && category.isNotEmpty) query['category'] = category;
    final finalUri = query.isEmpty
        ? uri
        : '$uri&${query.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    final list = await apiClient.getList(finalUri);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> createProduct(Map<String, dynamic> payload) async {
    if (!_usesLocalApi) {
      await DatabaseService.createProduct(
        name: payload['name']?.toString() ?? '',
        price: (payload['price'] as num?)?.toDouble() ?? 0,
        costPrice: (payload['costPrice'] as num?)?.toDouble() ?? 0,
        ivaRate: (payload['ivaRate'] as num?)?.toDouble() ?? 0,
        profitIva: (payload['profitIva'] as num?)?.toDouble() ?? 0,
        categoryName: payload['categoryName']?.toString(),
        sku: payload['sku']?.toString(),
        auxCode: payload['auxCode']?.toString(),
        description: payload['description']?.toString(),
        tags: payload['tags']?.toString(),
        storeId: (payload['storeId'] as num?)?.toInt(),
        images: List<String>.from(payload['images'] ?? const []),
        initialStock: _intMap(payload['initialStock']),
      );
      return;
    }
    await apiClient.postJson('/api/products', payload);
  }

  Future<List<Map<String, dynamic>>> getStores() async {
    if (!_usesLocalApi) return DatabaseService.getStores();
    final list = await apiClient.getList('/api/stores');
    return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    if (!_usesLocalApi) return DatabaseService.getCategories();
    final list = await apiClient.getList('/api/categories');
    return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<List<String>> getProductImageIds(int productId) async {
    if (!_usesLocalApi) return DatabaseService.getProductImageIds(productId);
    final list = await apiClient.getList('/api/products/$productId/images');
    return list.map((item) => item.toString()).toList();
  }

  Future<void> updateProduct(int id, Map<String, dynamic> payload) async {
    if (!_usesLocalApi) {
      final previousImages = await DatabaseService.getProductImageIds(id);
      final images = payload['images'] == null
          ? null
          : List<String>.from(payload['images'] as List);
      await DatabaseService.updateProduct(
        productId: id,
        name: payload['name']?.toString() ?? '',
        categoryName: payload['categoryName']?.toString() ?? '',
        sku: payload['sku']?.toString() ?? '',
        price: (payload['price'] as num?)?.toDouble() ?? 0,
        costPrice: (payload['costPrice'] as num?)?.toDouble() ?? 0,
        ivaRate: (payload['ivaRate'] as num?)?.toDouble() ?? 0,
        profitIva: (payload['profitIva'] as num?)?.toDouble() ?? 0,
        auxCode: payload['auxCode']?.toString(),
        description: payload['description']?.toString(),
        tags: payload['tags']?.toString(),
        storeId: (payload['storeId'] as num?)?.toInt(),
        images: images,
      );
      if (images != null) {
        for (final imagePath in previousImages.where(
          (item) => !images.contains(item),
        )) {
          await ImageStorageService.deleteImage(imagePath);
        }
      }
      for (final entry in _intMap(payload['stockByStore']).entries) {
        await DatabaseService.updateInventoryStock(
          productId: id,
          storeId: entry.key,
          stock: entry.value,
        );
      }
      return;
    }
    await apiClient.putJson('/api/products/$id', payload);
  }

  Future<void> deleteProduct(int id) async {
    if (!_usesLocalApi) {
      final imagePaths = await DatabaseService.getProductImageIds(id);
      await DatabaseService.deleteProduct(id);
      for (final imagePath in imagePaths) {
        await ImageStorageService.deleteImage(imagePath);
      }
      return;
    }
    await apiClient.deleteJson('/api/products/$id');
  }

  Future<void> removeImageReference(int productId, String imageRef) async {
    if (!_usesLocalApi) {
      final imageIds = await DatabaseService.getProductImageIds(productId);
      if (!imageIds.contains(imageRef)) return;
      await DatabaseService.updateProductImages(
        productId: productId,
        imageIds: imageIds.where((item) => item != imageRef).toList(),
      );
      await ImageStorageService.deleteImage(imageRef);
      return;
    }
    await apiClient.putJson('/api/products/$productId/images', {
      'imageRef': imageRef,
    });
  }

  bool get _usesLocalApi => AppPlatform.isDesktop || AppPlatform.isWeb;

  Map<int, int> _intMap(Object? value) {
    if (value is! Map) return const {};
    return value.map(
      (key, item) => MapEntry(
        int.parse(key.toString()),
        (item as num).toInt(),
      ),
    );
  }
}
