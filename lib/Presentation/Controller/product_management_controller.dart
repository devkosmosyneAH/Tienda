import 'dart:async';

import 'package:tienda/Presentation/Services/image_optimizer_service.dart';
import 'package:tienda/Presentation/Services/image_storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:tienda/repositories/products_repository.dart';
import 'package:tienda/websocket/local_server_websocket_client.dart';

class ProductManagementController extends ChangeNotifier {
  ProductManagementController({
    ProductsRepository? repository,
    LocalServerWebSocketClient? eventsClient,
  })  : _repository = repository ?? ProductsRepository(),
        _eventsClient = eventsClient ?? LocalServerWebSocketClient() {
    unawaited(_eventsClient.connect());
    _eventsSubscription = _eventsClient.events.listen((_) {
      if (!isLoading) {
        unawaited(loadCatalog());
      }
    });
  }

  final ProductsRepository _repository;
  final LocalServerWebSocketClient _eventsClient;
  late final StreamSubscription<Map<String, dynamic>> _eventsSubscription;

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

  @override
  void dispose() {
    _eventsSubscription.cancel();
    unawaited(_eventsClient.dispose());
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
      stores = await _repository.getStores();
      categories = await _repository.getCategories();
      products = await _repository.getProducts(
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
    await _repository.createProduct({
      'name': name,
      'price': price,
      'costPrice': costPrice,
      'ivaRate': ivaRate,
      'profitIva': profitIva,
      'categoryName': category,
      'sku': sku,
      'auxCode': auxCode,
      'description': description,
      'tags': tags,
      'storeId': storeId,
      'images': images,
      'initialStock': _serializeStock(initialStock),
    });
    await loadCatalog(); // ← Producto creado
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
    await _repository.updateProduct(
      productId,
      _productPayload(
        name: name,
        category: category,
        price: price,
        costPrice: costPrice,
        ivaRate: ivaRate,
        profitIva: profitIva,
        sku: sku,
        auxCode: auxCode,
        description: description,
        tags: tags,
        storeId: storeId,
        images: images,
      ),
    );
    await loadCatalog();
    // ← Producto actualizado
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
    final payload = _productPayload(
      name: name,
      category: category,
      price: price,
      costPrice: costPrice,
      ivaRate: ivaRate,
      profitIva: profitIva,
      sku: sku,
      auxCode: auxCode,
      description: description,
      tags: tags,
      storeId: storeId,
      images: images,
    );
    payload['stockByStore'] = _serializeStock(stockByStore);
    await _repository.updateProduct(productId, payload);
    await loadCatalog();
    // ← Producto + stock actualizado
  }

  Future<void> removeImageReference({
    int? productId,
    required String imageRef,
  }) async {
    final trimmed = imageRef.trim();
    if (trimmed.isEmpty) return;

    final isLocalImagePath = trimmed.contains('/') ||
        trimmed.contains('\\') ||
        trimmed.startsWith('file:');

    if (productId != null) {
      final currentIds = await _repository.getProductImageIds(productId);
      if (currentIds.contains(trimmed)) {
        await _repository.removeImageReference(productId, trimmed);
        await loadCatalog();
      }
    }

    if (isLocalImagePath && productId == null) {
      await ImageStorageService.deleteImage(trimmed);
    }
  }

  Future<void> deleteProduct(int productId) async {
    await _repository.deleteProduct(productId);
    await loadCatalog();
    // ← Producto eliminado
  }

  Map<String, dynamic> _productPayload({
    required String name,
    required String category,
    required double price,
    required double costPrice,
    required double ivaRate,
    required double profitIva,
    String? sku,
    String? auxCode,
    String? description,
    String? tags,
    int? storeId,
    List<String>? images,
  }) =>
      {
        'name': name,
        'categoryName': category,
        'sku': sku ?? '',
        'price': price,
        'costPrice': costPrice,
        'ivaRate': ivaRate,
        'profitIva': profitIva,
        'auxCode': auxCode,
        'description': description,
        'tags': tags,
        'storeId': storeId,
        if (images != null) 'images': images,
      };

  Map<String, int> _serializeStock(Map<int, int> stockByStore) =>
      stockByStore.map((storeId, stock) => MapEntry('$storeId', stock));
}
