import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tienda/Presentation/Model/product_model.dart';
import 'package:tienda/repositories/products_repository.dart';
import 'package:tienda/websocket/local_server_websocket_client.dart';

class ProductProvider extends ChangeNotifier {
  ProductProvider({
    ProductsRepository? repository,
    LocalServerWebSocketClient? eventsClient,
  })  : _repository = repository ?? ProductsRepository(),
        _eventsClient = eventsClient ?? LocalServerWebSocketClient() {
    unawaited(_eventsClient.connect());
    _eventsSubscription = _eventsClient.events.listen((_) {
      if (!isLoading) {
        unawaited(loadProducts(
            searchValue: search, categoryFilter: selectedCategory));
      }
    });
  }

  final ProductsRepository _repository;
  final LocalServerWebSocketClient _eventsClient;
  late final StreamSubscription<Map<String, dynamic>> _eventsSubscription;

  bool isLoading = false;
  String? errorMessage;
  String search = '';
  String? selectedCategory;

  List<Product> products = [];
  List<Product> filteredProducts = [];
  Product? selectedProduct;

  @override
  void dispose() {
    _eventsSubscription.cancel();
    unawaited(_eventsClient.dispose());
    super.dispose();
  }

  Future<void> initialize() async {
    if (isLoading || products.isNotEmpty) return;
    await loadProducts();
  }

  Future<void> loadProducts(
      {String searchValue = '', String? categoryFilter}) async {
    isLoading = true;
    search = searchValue;
    selectedCategory = categoryFilter;
    errorMessage = null;
    notifyListeners();

    try {
      final rawProducts = await _repository.getProducts(search: searchValue);
      products = rawProducts.map((p) => Product.fromMap(p)).toList();

      _filterProducts();
    } catch (e) {
      errorMessage = 'Error al cargar productos: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _filterProducts() {
    filteredProducts = products.where((product) {
      if (selectedCategory != null && product.category != selectedCategory) {
        return false;
      }
      if (search.isNotEmpty &&
          !product.name.toLowerCase().contains(search.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
    notifyListeners();
  }

  Future<void> createProduct({
    required String name,
    required double price,
    String? sku,
    String? categoryName,
    Map<int, int>? initialStock,
  }) async {
    try {
      await _repository.createProduct({
        'name': name,
        'price': price,
        'sku': sku,
        'categoryName': categoryName,
        'initialStock': (initialStock ?? const {}).map(
          (storeId, stock) => MapEntry('$storeId', stock),
        ),
      });
      await loadProducts(searchValue: search, categoryFilter: selectedCategory);
    } catch (e) {
      errorMessage = 'Error al crear producto: $e';
      notifyListeners();
    }
  }

  Future<void> updateProduct({
    required int productId,
    required String name,
    required String categoryName,
    required String sku,
    required double price,
  }) async {
    try {
      await _repository.updateProduct(productId, {
        'name': name,
        'categoryName': categoryName,
        'sku': sku,
        'price': price,
      });
      await loadProducts(searchValue: search, categoryFilter: selectedCategory);
    } catch (e) {
      errorMessage = 'Error al actualizar producto: $e';
      notifyListeners();
    }
  }

  void selectProduct(Product product) {
    selectedProduct = product;
    notifyListeners();
  }

  void clearSelection() {
    selectedProduct = null;
    notifyListeners();
  }

  List<String> get categories {
    final Set<String> cats = {};
    for (var product in products) {
      if (product.category != null) {
        cats.add(product.category!);
      }
    }
    return cats.toList();
  }

  int get lowStockCount =>
      products.where((p) => p.isLowStock && p.isActive).length;

  double get totalInventoryValue =>
      products.fold(0, (sum, p) => sum + p.totalInventoryValue);
}
