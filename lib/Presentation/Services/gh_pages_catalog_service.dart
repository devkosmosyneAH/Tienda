// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// Modelos del catálogo web (GitHub Pages)
// ─────────────────────────────────────────────────────────────────────────────

/// Manifiesto de versión leído desde GitHub Pages.
class GhPagesManifest {
  final int version;
  final String updatedAt;
  final int productsCount;
  final int categoriesCount;
  final int? totalPages;
  final int? pageSize;

  const GhPagesManifest({
    required this.version,
    required this.updatedAt,
    required this.productsCount,
    required this.categoriesCount,
    this.totalPages,
    this.pageSize,
  });

  factory GhPagesManifest.fromJson(Map<String, dynamic> json) =>
      GhPagesManifest(
        version: (json['version'] as num).toInt(),
        updatedAt: json['updatedAt'] as String,
        productsCount: (json['productsCount'] as num).toInt(),
        categoriesCount: (json['categoriesCount'] as num).toInt(),
        totalPages: (json['totalPages'] as num?)?.toInt(),
        pageSize: (json['pageSize'] as num?)?.toInt(),
      );

  bool get isPaginated => totalPages != null && totalPages! > 1;
}

/// Producto del catálogo público (leído desde products.json).
class GhPagesProduct {
  final int id;
  final String? uid;
  final String name;
  final String? sku;
  final String? description;
  final String? tags;
  final double price;
  final double ivaRate;
  final String? category;
  final List<String> images;
  final int totalStock;
  final bool isActive;

  const GhPagesProduct({
    required this.id,
    this.uid,
    required this.name,
    this.sku,
    this.description,
    this.tags,
    required this.price,
    required this.ivaRate,
    this.category,
    required this.images,
    required this.totalStock,
    required this.isActive,
  });

  factory GhPagesProduct.fromJson(Map<String, dynamic> json) => GhPagesProduct(
        id: (json['id'] as num).toInt(),
        uid: json['uid'] as String?,
        name: json['name'] as String,
        sku: json['sku'] as String?,
        description: json['description'] as String?,
        tags: json['tags'] as String?,
        price: (json['price'] as num).toDouble(),
        ivaRate: ((json['ivaRate'] ?? 0) as num).toDouble(),
        category: json['category'] as String?,
        images: (json['images'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        totalStock: ((json['totalStock'] ?? 0) as num).toInt(),
        isActive: (json['isActive'] as bool?) ?? true,
      );
}

/// Categoría del catálogo público (leída desde categories.json).
class GhPagesCategory {
  final int id;
  final String name;

  const GhPagesCategory({required this.id, required this.name});

  factory GhPagesCategory.fromJson(Map<String, dynamic> json) =>
      GhPagesCategory(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
      );
}

/// Datos completos del catálogo cargados desde GitHub Pages.
class GhPagesCatalog {
  final GhPagesManifest manifest;
  final List<GhPagesProduct> products;
  final List<GhPagesCategory> categories;

  const GhPagesCatalog({
    required this.manifest,
    required this.products,
    required this.categories,
  });

  /// Productos agrupados por categoría (para construir la UI).
  Map<String, List<GhPagesProduct>> get productsByCategory {
    final result = <String, List<GhPagesProduct>>{};
    for (final product in products) {
      if (!product.isActive) continue;
      final cat = product.category ?? 'Sin categoría';
      result.putIfAbsent(cat, () => []).add(product);
    }
    return result;
  }

  /// Categorías únicas presentes en los productos activos.
  List<String> get activeCategories => productsByCategory.keys.toList()..sort();
}

// ─────────────────────────────────────────────────────────────────────────────
// Servicio de descarga desde GitHub Pages
// ─────────────────────────────────────────────────────────────────────────────

/// Descarga y cachea el catálogo desde GitHub Pages.
///
/// Caché inteligente basada en la versión del manifest.json:
///   • Si la versión remota > versión cacheada → descarga datos frescos.
///   • Si la versión es la misma → devuelve caché sin peticiones extras.
///
/// Configurar la URL base de GitHub Pages:
/// ```dart
/// GhPagesCatalogService.baseUrl = 'https://tuusuario.github.io/tu-repo/catalog';
/// ```
class GhPagesCatalogService {
  /// URL base donde están los JSON exportados.
  /// Debe terminar SIN barra final.
  /// Ejemplo: 'https://bazarypapelerianicole.github.io/PlatformWeb/#/catalog'
  static String baseUrl =
      'https://bazarypapelerianicole.github.io/PlatformWeb/#/catalog';

  // ── Caché en memoria ───────────────────────────────────────────────────────
  static GhPagesCatalog? _cache;
  static int _cachedVersion = -1;

  // ── API pública ────────────────────────────────────────────────────────────

  /// Carga el catálogo completo.
  /// Si la versión remota no cambió, devuelve la caché sin descargar nada más.
  static Future<GhPagesCatalog> loadCatalog() async {
    // 1. Descargar manifest para comprobar versión.
    final manifest = await _fetchManifest();

    // 2. Caché válida: devolver sin descargar.
    if (_cache != null && manifest.version == _cachedVersion) {
      print('[GhPagesCatalogService] ✅ Caché válida (versión ${manifest.version}).');
      return _cache!;
    }

    print('[GhPagesCatalogService] 🔄 Versión nueva '
        '(local=$_cachedVersion → remota=${manifest.version}). Descargando…');

    // 3. Descargar datos frescos.
    final products = manifest.isPaginated
        ? await _fetchAllPages(manifest)
        : await _fetchProducts();

    final categories = await _fetchCategories();

    final catalog = GhPagesCatalog(
      manifest: manifest,
      products: products,
      categories: categories,
    );

    // Actualizar caché.
    _cache = catalog;
    _cachedVersion = manifest.version;

    return catalog;
  }

  /// Invalida la caché manualmente (fuerza descarga completa en el siguiente [loadCatalog]).
  static void invalidateCache() {
    _cache = null;
    _cachedVersion = -1;
  }

  // ── Privados ───────────────────────────────────────────────────────────────

  static Future<GhPagesManifest> _fetchManifest() async {
    final json = await _fetchJson('$baseUrl/manifest.json');
    return GhPagesManifest.fromJson(json as Map<String, dynamic>);
  }

  static Future<List<GhPagesProduct>> _fetchProducts() async {
    final list = await _fetchJson('$baseUrl/products.json') as List<dynamic>;
    return list
        .map((e) => GhPagesProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<GhPagesProduct>> _fetchAllPages(
      GhPagesManifest manifest) async {
    final total = manifest.totalPages!;
    final futures = List.generate(
      total,
      (i) => _fetchPageProducts(i + 1),
    );
    final pages = await Future.wait(futures);
    return pages.expand((p) => p).toList();
  }

  static Future<List<GhPagesProduct>> _fetchPageProducts(int page) async {
    final list =
        await _fetchJson('$baseUrl/products_page_$page.json') as List<dynamic>;
    return list
        .map((e) => GhPagesProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<GhPagesCategory>> _fetchCategories() async {
    final list =
        await _fetchJson('$baseUrl/categories.json') as List<dynamic>;
    return list
        .map((e) => GhPagesCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<dynamic> _fetchJson(String url) async {
    print('[GhPagesCatalogService] GET $url');
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'HTTP ${response.statusCode} al obtener $url',
      );
    }

    return jsonDecode(response.body);
  }
}
