import 'package:tienda/Presentation/Repository/product_repository.dart';
import 'package:tienda/Presentation/Services/catalog_sync_service.dart';
import 'package:tienda/Presentation/Services/audit_service.dart';
import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:tienda/Presentation/Services/google_drive_backup_service.dart';
import 'package:tienda/Presentation/Services/image_optimizer_service.dart';
import 'package:flutter/foundation.dart';

class ProductManagementController extends ChangeNotifier {
  ProductManagementController({
    ProductRepository? productRepository,
  }) : _productRepository = productRepository ?? const DatabaseProductRepository() {
    DatabaseService.addDatabaseListener(_handleDatabaseChanged);
  }

  final ProductRepository _productRepository;

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
          debugPrint('Subiendo imagen...');

          final fileId = await GoogleDriveBackupService.uploadProductImage(
            optimized.file.path,
          );
          debugPrint('Subida completada: $fileId');
          return fileId;
        } catch (e) {
          debugPrint('Error al optimizar/subir $localPath: $e');
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
      stores = await _productRepository.getStores();
      categories = await _productRepository.getCategories();
      products = await _productRepository.getProducts(
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
    try {
      final productId = await _productRepository.createProduct(
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
      final created = await DatabaseService.rawQuery(
        'SELECT * FROM products WHERE id = ? LIMIT 1', [productId],
      );
      await AuditService.log(
        action: AuditAction.createProduct, module: 'Products',
        page: 'ProductManagementView', entity: 'product',
        entityId: created.isEmpty ? null : created.first['id'],
        newData: created.isEmpty ? null : created.first,
        controller: 'ProductManagementController',
      );
      await loadCatalog();
      CatalogSyncService.instance.markDirty();
    } catch (error) {
      await AuditService.log(
        action: AuditAction.createProduct, module: 'Products',
        page: 'ProductManagementView', controller: 'ProductManagementController',
        success: false, error: error,
      );
      rethrow;
    }
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
    final previousImages = await _productRepository.getProductImageIds(productId);
    final before = await DatabaseService.rawQuery(
      'SELECT * FROM products WHERE id = ? LIMIT 1', [productId],
    );
    try {
      await _productRepository.updateProduct(
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
      for (final oldId in previousImages.where((id) => !current.contains(id))) {
        await GoogleDriveBackupService.deleteProductImage(oldId);
      }
      }
      final after = await DatabaseService.rawQuery(
        'SELECT * FROM products WHERE id = ? LIMIT 1', [productId],
      );
      await AuditService.log(
        action: AuditAction.updateProduct, module: 'Products',
        page: 'ProductManagementView', entity: 'product', entityId: productId,
        oldData: before.isEmpty ? null : before.first,
        newData: after.isEmpty ? null : after.first,
        controller: 'ProductManagementController',
      );
      await loadCatalog();
      CatalogSyncService.instance.markDirty();
    } catch (error) {
      await AuditService.log(
        action: AuditAction.updateProduct, module: 'Products',
        page: 'ProductManagementView', entity: 'product', entityId: productId,
        oldData: before.isEmpty ? null : before.first,
        controller: 'ProductManagementController', success: false, error: error,
      );
      rethrow;
    }
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
    final previousImages = await _productRepository.getProductImageIds(productId);
    await _productRepository.updateProduct(
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
      for (final oldId in previousImages.where((id) => !current.contains(id))) {
        await GoogleDriveBackupService.deleteProductImage(oldId);
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

    final isDriveReference = !trimmed.contains('/') && !trimmed.contains('\\');

    if (productId != null) {
      final currentIds = await _productRepository.getProductImageIds(productId);
      if (currentIds.contains(trimmed)) {
        final remainingIds = currentIds.where((id) => id != trimmed).toList();
        await _productRepository.updateProductImages(
          productId: productId,
          imageIds: remainingIds,
        );
        CatalogSyncService.instance.markDirty();
        await loadCatalog();
      }
    }

    if (isDriveReference) {
      await GoogleDriveBackupService.deleteProductImage(trimmed);
    }
  }

  Future<void> deleteProduct(int productId) async {
    final imageIds = await _productRepository.getProductImageIds(productId);
    final before = await DatabaseService.rawQuery(
      'SELECT * FROM products WHERE id = ? LIMIT 1', [productId],
    );
    try {
      await _productRepository.deleteProduct(productId);
      await AuditService.log(
        action: AuditAction.deleteProduct, module: 'Products',
        page: 'ProductManagementView', entity: 'product', entityId: productId,
        oldData: before.isEmpty ? null : before.first,
        controller: 'ProductManagementController',
      );
    } catch (error) {
      await AuditService.log(
        action: AuditAction.deleteProduct, module: 'Products',
        page: 'ProductManagementView', entity: 'product', entityId: productId,
        oldData: before.isEmpty ? null : before.first,
        controller: 'ProductManagementController', success: false, error: error,
      );
      rethrow;
    }
    for (final id in imageIds) {
      await GoogleDriveBackupService.deleteProductImage(id);
    }
    await loadCatalog();
    CatalogSyncService.instance.markDirty(); // ← Producto eliminado
  }
}
