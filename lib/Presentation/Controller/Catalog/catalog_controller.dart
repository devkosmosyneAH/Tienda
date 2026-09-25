import 'package:flutter/foundation.dart';
import 'package:tienda/Presentation/Template/catalog_template.dart';
import '../../View/Catalog/catalog_repository.dart';

/// Controlador del catálogo web. Mantiene el estado en memoria y evita
/// descargas repetidas de JSON cuando el usuario navega entre rutas.
class CatalogController extends ChangeNotifier {
  final CatalogRepository repository;

  CatalogController({required this.repository});

  bool isLoading = false;
  bool isReady = false;
  String? errorMessage;
  CatalogRepositoryData? _catalogData;

  String currentSearch = '';
  String? selectedCategoryId;
  String? selectedStoreId;

  List<CatalogSection> get sections => _catalogData?.driveData.sections ?? [];

  bool get hasSections => sections.isNotEmpty;

  Future<void> initialize({bool forceRefresh = false}) async {
    if (isReady && !forceRefresh) return;
    if (isLoading) return;

    debugPrint('[CatalogController] initialize START');
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      _catalogData = await repository.loadCatalog();
      isReady = true;
    } catch (error) {
      errorMessage = error.toString();
      debugPrint('[CatalogController] initialize ERROR: $error');
    } finally {
      isLoading = false;
      debugPrint('[CatalogController] initialize END');
      notifyListeners();
    }
  }

  void refresh() => initialize(forceRefresh: true);

  CatalogProductEntry? productBySku(String sku) {
    final searchKey = sku.trim().toLowerCase();
    return _catalogData?.skuIndex[searchKey];
  }

  CatalogProductEntry? productByRouteKey(String key) {
    final data = _catalogData;
    if (data == null) return null;

    final trimmedKey = key.trim();
    final lowerKey = trimmedKey.toLowerCase();
    final skuMatch = data.skuIndex[lowerKey];
    if (skuMatch != null) return skuMatch;

    final products = data.driveData.sections
        .expand((section) => section.categories)
        .expand((category) => category.products)
        .toList();
    for (final product in products) {
      if (product.id.toString() == trimmedKey) return product;
    }

    final routeKey = _normalizeRouteKey(key);
    if (routeKey.isEmpty) return null;

    for (final product in products) {
      if (_normalizeRouteKey(product.name) == routeKey) {
        return product;
      }
    }
    return null;
  }

  static String _normalizeRouteKey(String value) {
    var normalized = value.trim().toLowerCase();
    const replacements = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    replacements.forEach((from, to) {
      normalized = normalized.replaceAll(from, to);
    });
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return normalized.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  CatalogCategory? categoryById(String categoryId) {
    return _catalogData?.categoryIndex[categoryId];
  }

  CatalogSection? storeById(String storeId) {
    return _catalogData?.storeIndex[storeId];
  }

  List<CatalogProductEntry> searchProducts(String query) {
    final trimmed = query.trim().toLowerCase();
    if (_catalogData == null) return const [];

    final productLists = _catalogData!.driveData.sections
        .expand((section) => section.categories)
        .expand((category) => category.products);

    if (trimmed.isEmpty) {
      return productLists.toList();
    }

    return productLists
        .where(
          (product) =>
              product.name.toLowerCase().contains(trimmed) ||
              product.sku.toLowerCase().contains(trimmed),
        )
        .toList();
  }
}
