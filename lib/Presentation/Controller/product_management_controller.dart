import 'package:tienda/Presentation/Services/catalog_sync_service.dart';
import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:tienda/Presentation/Services/image_optimizer_service.dart';
import 'package:tienda/Presentation/Services/image_storage_service.dart';
import 'package:flutter/foundation.dart';

class ProductManagementController extends ChangeNotifier {
  ProductManagementController() {
    DatabaseService.addDatabaseListener(_handleDatabaseChanged);
  }

  bool isLoading = false;
  String? errorMessage;
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> stores = [];
  List<Map<String, dynamic>> categories = [];

  Future<List<String>> uploadImages(List<String> localPaths) async {
    return Future.wait(
      localPaths.map((localPath) async {
        OptimizedImage? optimized;
        try {
          debugPrint('Optimizando imagen...');
          optimized = await ImageOptimizerService.optimize(
            localPath,
            onProgress: (step) => debugPrint(step),
          );

          debugPrint('Optimización completada: ${optimized.file.path}');
          debugPrint('Guardando imagen en carpeta local...');

          final savedPath = await ImageStorageService.saveImageFile(
            optimized.file.path,
          );
          debugPrint('Imagen guardada en: $savedPath');
          return savedPath;
        } catch (e) {
          debugPrint('Error al optimizar/guardar $localPath: $e');
          rethrow;
        } finally {
          if (optimized != null) {
            try {
              if (await optimized.file.exists()) {
                await optimized.file.delete();
                debugPrint('Temporal eliminado: ${optimized.file.path}');
              }
            } catch (e) {
              debugPrint('No se pudo eliminar temporal: $e');
            }
          }
        }
      }),
    );
  }

  void _handleDatabaseChanged() {
    if (!isLoading) {
      loadCatalog();
    }
  }

  @override
  void dispose() {
    DatabaseService.removeDatabaseListener(_handleDatabaseChanged);
    super.dispose();
  }

  Future<void> initialize() async {
    if (isLoading || products.isNotEmpty) return;
    await loadCatalog();
  }

  Future<void> loadCatalog({
    String search = '',
    int? storeId,
    String? category,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      stores = await DatabaseService.getStores();
      categories = await DatabaseService.getCategories();
      products = await DatabaseService.getProducts(
        search: search,
        storeId: storeId,
        category: category,
      );
    } catch (e) {
      errorMessage = 'No se pudo cargar el catálogo: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createProduct({
    required String name,
    required String category,
    required double price,
    double costPrice = 0,
    double ivaRate = 0,
    double profitIva = 0,
    String? sku,
    String? auxCode,
    String? description,
    String? tags,
    int? storeId,
    List<String> images = const [],
    Map<int, int> initialStock = const {},
  }) async {
    await DatabaseService.createProduct(
      name: name,
      price: price,
      costPrice: costPrice,
      ivaRate: ivaRate,
      profitIva: profitIva,
      categoryName: category,
      sku: sku,
      auxCode: auxCode,
      description: description,
      tags: tags,
      storeId: storeId,
      images: images,
      initialStock: initialStock,
    );
    await loadCatalog();
    CatalogSyncService.instance.markDirty(); // ← Producto creado
  }

  Future<void> updateProduct({
    required int productId,
    required String name,
    required String category,
    required double price,
    double costPrice = 0,
    double ivaRate = 0,
    double profitIva = 0,
    String? sku,
    String? auxCode,
    String? description,
    String? tags,
    int? storeId,
    List<String>? images,
  }) async {
    final previousImages = await DatabaseService.getProductImageIds(productId);
    await DatabaseService.updateProduct(
      productId: productId,
      name: name,
      categoryName: category,
      sku: sku ?? '',
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
    if (images != null) {
      final current = images.toSet();
      for (final oldPath in previousImages.where((id) => !current.contains(id))) {
        await ImageStorageService.deleteImage(oldPath);
      }
    }
    await loadCatalog();
    CatalogSyncService.instance.markDirty(); // ← Producto actualizado
  }

  Future<void> updateProductWithStock({
    required int productId,
    required String name,
    required String category,
    required double price,
    double costPrice = 0,
    double ivaRate = 0,
    double profitIva = 0,
    String? sku,
    String? auxCode,
    String? description,
    String? tags,
    int? storeId,
    List<String>? images,
    Map<int, int> stockByStore = const {},
  }) async {
    final previousImages = await DatabaseService.getProductImageIds(productId);
    await DatabaseService.updateProduct(
      productId: productId,
      name: name,
      categoryName: category,
      sku: sku ?? '',
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
    if (images != null) {
      final current = images.toSet();
      for (final oldPath in previousImages.where((id) => !current.contains(id))) {
        await ImageStorageService.deleteImage(oldPath);
      }
    }
    for (final entry in stockByStore.entries) {
      await DatabaseService.updateInventoryStock(
        productId: productId,
        storeId: entry.key,
        stock: entry.value,
      );
    }
    await loadCatalog();
    CatalogSyncService.instance.markDirty(); // ← Producto + stock actualizado
  }

  Future<void> removeImageReference({
    int? productId,
    required String imageRef,
  }) async {
    final trimmed = imageRef.trim();
    if (trimmed.isEmpty) return;

    final isLocalImagePath = trimmed.contains('/') || trimmed.contains('\\') || trimmed.startsWith('file:');

    if (productId != null) {
      final currentIds = await DatabaseService.getProductImageIds(productId);
      if (currentIds.contains(trimmed)) {
        final remainingIds = currentIds.where((id) => id != trimmed).toList();
        await DatabaseService.updateProductImages(
          productId: productId,
          imageIds: remainingIds,
        );
        CatalogSyncService.instance.markDirty();
        await loadCatalog();
      }
    }

    if (isLocalImagePath) {
      await ImageStorageService.deleteImage(trimmed);
    }
  }

  Future<void> deleteProduct(int productId) async {
    final imagePaths = await DatabaseService.getProductImageIds(productId);
    await DatabaseService.deleteProduct(productId);
    for (final path in imagePaths) {
      await ImageStorageService.deleteImage(path);
    }
    await loadCatalog();
    CatalogSyncService.instance.markDirty(); // ← Producto eliminado
  }
}
