// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'database_service.dart';

/// Modelos JSON de catálogo ─────────────────────────────────────────────────

/// Producto serializable para el catálogo público.
/// Solo expone campos necesarios para la vitrina web:
/// precio, descripción, imágenes (URLs Drive), categoría y stock total.
class CatalogProductJson {
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

  const CatalogProductJson({
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'uid': uid,
        'name': name,
        'sku': sku,
        'description': description,
        'tags': tags,
        'price': price,
        'ivaRate': ivaRate,
        'category': category,
        'images': images,
        'totalStock': totalStock,
        'isActive': isActive,
      };

  factory CatalogProductJson.fromDbRow(Map<String, dynamic> row) {
    final rawImages = row['images'] as String? ?? '';
    return CatalogProductJson(
      id: (row['id'] as num).toInt(),
      uid: row['uid'] as String?,
      name: row['name'] as String,
      sku: row['sku'] as String?,
      description: row['description'] as String?,
      tags: row['tags'] as String?,
      price: (row['price'] as num).toDouble(),
      ivaRate: ((row['iva_rate'] ?? row['ivaRate'] ?? 0) as num).toDouble(),
      category: row['category'] as String?,
      images:
          rawImages.isNotEmpty ? rawImages.split(',').map((s) => s.trim()).toList() : [],
      totalStock: ((row['total_stock'] ?? row['totalStock'] ?? 0) as num).toInt(),
      isActive: ((row['is_active'] ?? row['isActive']) as bool?) ?? true,
    );
  }
}

/// Categoría serializable para el catálogo público.
class CatalogCategoryJson {
  final int id;
  final String name;

  const CatalogCategoryJson({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory CatalogCategoryJson.fromDbRow(Map<String, dynamic> row) =>
      CatalogCategoryJson(
        id: (row['id'] as num).toInt(),
        name: row['name'] as String,
      );
}

/// Manifiesto de versión para caché inteligente en el cliente web.
class CatalogManifest {
  final int version;
  final String updatedAt;
  final int productsCount;
  final int categoriesCount;
  final String? catalogHash;

  // Particionado futuro: cuántas páginas existen cuando >10.000 productos.
  final int? totalPages;
  final int? pageSize;

  const CatalogManifest({
    required this.version,
    required this.updatedAt,
    required this.productsCount,
    required this.categoriesCount,
    this.catalogHash,
    this.totalPages,
    this.pageSize,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'updatedAt': updatedAt,
        'productsCount': productsCount,
        'categoriesCount': categoriesCount,
        if (catalogHash != null) 'catalogHash': catalogHash,
        if (totalPages != null) 'totalPages': totalPages,
        if (pageSize != null) 'pageSize': pageSize,
      };
}

/// Resultado de una exportación completa.
class ExportResult {
  final bool success;
  final int productsCount;
  final int categoriesCount;
  final String exportDir;
  final String? error;
  final DateTime timestamp;

  const ExportResult({
    required this.success,
    required this.productsCount,
    required this.categoriesCount,
    required this.exportDir,
    this.error,
    required this.timestamp,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Servicio de exportación SQLite → JSON
// ─────────────────────────────────────────────────────────────────────────────

/// Exporta productos y categorías desde SQLite a archivos JSON listos para
/// ser publicados en GitHub Pages.
///
/// Genera en [exportDir]:
///   • products.json
///   • categories.json
///   • manifest.json
///
/// Particionado automático cuando [_pageSize] es superado (preparado para
/// catálogos de más de 10.000 productos).
class CatalogExportService {
  // Número de productos por página (particionado futuro).
  static const int _pageSize = 500;

  // ── API pública ────────────────────────────────────────────────────────────

  /// Ejecuta exportación completa.
  /// Devuelve [ExportResult] con el estado y estadísticas.
  static Future<ExportResult> exportAll(String exportDir) async =>
      exportAllWithHash(exportDir);

  /// Exportación completa con hash opcional para el manifest.json.
  /// [catalogHash] es el SHA-256 del catálogo calculado previamente.
  static Future<ExportResult> exportAllWithHash(
    String exportDir, {
    String? catalogHash,
  }) async {
    try {
      final products = await _fetchProducts();
      final categories = await _fetchCategories();

      await _ensureDir(exportDir);
      await exportProducts(products, exportDir);
      await exportCategories(categories, exportDir);
      await generateManifest(
        exportDir: exportDir,
        productsCount: products.length,
        categoriesCount: categories.length,
        catalogHash: catalogHash,
      );

      print('[CatalogExportService] ✅ Exportados: '
          '${products.length} productos, ${categories.length} categorías');

      return ExportResult(
        success: true,
        productsCount: products.length,
        categoriesCount: categories.length,
        exportDir: exportDir,
        timestamp: DateTime.now(),
      );
    } catch (e, st) {
      print('[CatalogExportService] ❌ Error en exportAll: $e\n$st');
      return ExportResult(
        success: false,
        productsCount: 0,
        categoriesCount: 0,
        exportDir: exportDir,
        error: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  // ── Exportación de productos ───────────────────────────────────────────────

  /// Escribe products.json (o products_page_N.json si hay particionado).
  static Future<void> exportProducts(
    List<CatalogProductJson> products,
    String exportDir,
  ) async {
    // Solo productos activos en el catálogo web.
    final active = products.where((p) => p.isActive).toList();

    if (active.length <= _pageSize) {
      // Caso normal: archivo único.
      final file = File(p.join(exportDir, 'products.json'));
      final json = const JsonEncoder.withIndent('  ')
          .convert(active.map((e) => e.toJson()).toList());
      await file.writeAsString(json, encoding: utf8);
    } else {
      // Particionado: products_page_1.json, products_page_2.json, …
      final chunks = _chunk(active, _pageSize);
      for (var i = 0; i < chunks.length; i++) {
        final file = File(p.join(exportDir, 'products_page_${i + 1}.json'));
        final json = const JsonEncoder.withIndent('  ')
            .convert(chunks[i].map((e) => e.toJson()).toList());
        await file.writeAsString(json, encoding: utf8);
      }
    }
  }

  // ── Exportación de categorías ──────────────────────────────────────────────

  /// Escribe categories.json.
  static Future<void> exportCategories(
    List<CatalogCategoryJson> categories,
    String exportDir,
  ) async {
    final file = File(p.join(exportDir, 'categories.json'));
    final json = const JsonEncoder.withIndent('  ')
        .convert(categories.map((e) => e.toJson()).toList());
    await file.writeAsString(json, encoding: utf8);
  }

  // ── Manifiesto de versión ──────────────────────────────────────────────────

  /// Escribe manifest.json.
  /// La versión se incrementa automáticamente respecto al manifiesto anterior.
  static Future<void> generateManifest({
    required String exportDir,
    required int productsCount,
    required int categoriesCount,
    String? catalogHash,
  }) async {
    final manifestFile = File(p.join(exportDir, 'manifest.json'));

    // Leer versión anterior para incrementar.
    int previousVersion = 0;
    if (await manifestFile.exists()) {
      try {
        final raw = await manifestFile.readAsString(encoding: utf8);
        final map = jsonDecode(raw) as Map<String, dynamic>;
        previousVersion = (map['version'] as int?) ?? 0;
      } catch (_) {
        previousVersion = 0;
      }
    }

    // Calcular totalPages solo si hay particionado.
    final int? totalPages =
        productsCount > _pageSize ? (productsCount / _pageSize).ceil() : null;

    final manifest = CatalogManifest(
      version: previousVersion + 1,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      productsCount: productsCount,
      categoriesCount: categoriesCount,
      catalogHash: catalogHash,
      totalPages: totalPages,
      pageSize: totalPages != null ? _pageSize : null,
    );

    final json =
        const JsonEncoder.withIndent('  ').convert(manifest.toJson());
    await manifestFile.writeAsString(json, encoding: utf8);
  }

  // ── Helpers privados ───────────────────────────────────────────────────────

  static Future<List<CatalogProductJson>> _fetchProducts() async {
    final rows = await DatabaseService.getProducts();
    return rows.map(CatalogProductJson.fromDbRow).toList();
  }

  static Future<List<CatalogCategoryJson>> _fetchCategories() async {
    final rows = await DatabaseService.getCategories();
    return rows.map(CatalogCategoryJson.fromDbRow).toList();
  }

  static Future<void> _ensureDir(String dir) async {
    final directory = Directory(dir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  static List<List<T>> _chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, (i + size).clamp(0, list.length)));
    }
    return chunks;
  }
}
