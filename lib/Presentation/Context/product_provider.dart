import 'package:flutter/foundation.dart';
import 'package:tienda/Presentation/Model/product_model.dart';
import 'package:tienda/Presentation/Services/database_service.dart';

class ProductProvider extends ChangeNotifier {
  ProductProvider() {
    DatabaseService.addDatabaseListener(_handleDatabaseChanged);
  }

  bool isLoading = false;
  String? errorMessage;
  String search = '';
  String? selectedCategory;

  List<Product> products = [];
  List<Product> filteredProducts = [];
  Product? selectedProduct;

  void _handleDatabaseChanged() {
    if (!isLoading) {
      loadProducts();
    }
  }

  @override
  void dispose() {
    DatabaseService.removeDatabaseListener(_handleDatabaseChanged);
    super.dispose();
  }

  Future<void> initialize() async {
    if (isLoading || products.isNotEmpty) return;
    await loadProducts();
  }

  Future<void> loadProducts({String searchValue = '', String? categoryFilter}) async {
    isLoading = true;
    search = searchValue;
    selectedCategory = categoryFilter;
    errorMessage = null;
    notifyListeners();

    try {
      final rawProducts = await DatabaseService.getProducts(search: searchValue);
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
      await DatabaseService.createProduct(
        name: name,
        price: price,
        sku: sku,
        categoryName: categoryName,
        initialStock: initialStock ?? {},
      );
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
      await DatabaseService.updateProduct(
        productId: productId,
        name: name,
        categoryName: categoryName,
        sku: sku,
        price: price,
      );
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
