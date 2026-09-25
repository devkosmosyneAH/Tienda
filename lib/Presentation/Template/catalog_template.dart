// ===========================================================================
// catalog_template.dart
// Catálogo 100% dinámico construido desde Google Drive (products.json /
// categories.json).  No contiene ninguna lista ni mapa estático de categorías.
// ===========================================================================

// ── Modelos ─────────────────────────────────────────────────────────────────

/// Archivo de imagen tal como lo devuelve la API de Google Drive.
///
/// [thumbnailLink] contiene la URL pública de miniatura usada por la UI.
class CatalogImageFile {
  final String id;
  final String name;
  final String thumbnailLink;

  const CatalogImageFile({
    required this.id,
    required this.name,
    required this.thumbnailLink,
  });
}

/// Producto mínimo expuesto en el catálogo público.
class CatalogProductEntry {
  final int id;
  final String name;
  final String sku;
  final String description;
  final double price;
  final int stock;
  final int? categoryId;
  final String categoryName;

  /// Portada remota definida en categories.json para el encabezado del detalle.
  final String categoryImageUrl;

  /// Archivos de Drive asociados al producto, con su thumbnail público.
  final List<CatalogImageFile> imageFiles;

  const CatalogProductEntry({
    required this.id,
    required this.name,
    required this.sku,
    this.description = '',
    this.price = 0,
    this.stock = 0,
    this.categoryId,
    this.categoryName = 'Sin categoría',
    this.categoryImageUrl = '',
    this.imageFiles = const [],
  });
}

/// Categoría con sus productos y metadatos de visualización.
class CatalogCategory {
  final int id;
  final String name;
  final int storeId;
  final String storeName;
  final CatalogImageFile? imageFile;
  final String imageUrl;

  /// Imágenes de todos los productos de la categoría para su encabezado.
  ///
  /// [imageFile] se conserva como acceso compatible a la primera imagen.
  final List<CatalogImageFile> heroImages;
  final String description;
  final List<String> tags;
  final List<CatalogProductEntry> products;

  const CatalogCategory({
    required this.id,
    required this.name,
    required this.storeId,
    this.storeName = '',
    this.imageFile,
    this.imageUrl = '',
    this.heroImages = const [],
    this.description = '',
    this.tags = const [],
    this.products = const [],
  });

  CatalogCategory copyWith({
    List<CatalogProductEntry>? products,
    CatalogImageFile? imageFile,
    String? imageUrl,
    List<CatalogImageFile>? heroImages,
    String? description,
    List<String>? tags,
  }) => CatalogCategory(
    id: id,
    name: name,
    storeId: storeId,
    storeName: storeName,
    imageFile: imageFile ?? this.imageFile,
    imageUrl: imageUrl ?? this.imageUrl,
    heroImages: heroImages ?? this.heroImages,
    description: description ?? this.description,
    tags: tags ?? this.tags,
    products: products ?? this.products,
  );
}

/// Sección del catálogo agrupada por tienda.
class CatalogSection {
  final int storeId;
  final String storeName;
  final List<CatalogCategory> categories;

  const CatalogSection({
    required this.storeId,
    required this.storeName,
    required this.categories,
  });
}

// ── Compatibilidad hacia atrás ───────────────────────────────────────────────

/// Alias de [CatalogCategory]. Mantiene compatibilidad con widgets existentes.
typedef CategoryInfo = CatalogCategory;

// ── Enum de tienda ───────────────────────────────────────────────────────────

enum CatalogStore {
  bazar(1, 'Bazar', 'Artículos de bazar, regalos y accesorios'),
  tienda(2, 'Tienda', 'Papelería, belleza, alimentos y productos varios');

  final int id;
  final String label;
  final String description;
  const CatalogStore(this.id, this.label, this.description);

  static CatalogStore? fromId(int id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

// ── Utilidades ───────────────────────────────────────────────────────────────

/// Retorna el nombre de la tienda a partir de su ID.
/// 1 → Bazar | 2 → Tienda | otro → General
String getStoreName(int storeId) {
  switch (storeId) {
    case 1:
      return 'Bazar';
    case 2:
      return 'Tienda';
    default:
      return 'General';
  }
}

/// Retorna el [CatalogStore] correspondiente a un [storeId], o null.
CatalogStore? storeFromId(int storeId) => CatalogStore.fromId(storeId);

// ── Servicio de construcción del catálogo ────────────────────────────────────

/// Construye las secciones del catálogo a partir de los datos crudos de Drive.
class CatalogBuilder {
  CatalogBuilder._();

  // ── Construcción desde JSON crudo ─────────────────────────────────────────

  /// Construye [CatalogSection]s a partir de los JSON sin procesar de Drive.
  ///
  /// - [productsJson]    → contenido de products.json
  /// - [categoriesJson]  → contenido de categories.json
  /// - [storesJson]      → contenido de stores.json (opcional)
  /// - [imageFiles] → archivos de imagen con su `thumbnailLink` de Drive
  static List<CatalogSection> buildFromJson({
    required List<Map<String, dynamic>> productsJson,
    required List<Map<String, dynamic>> categoriesJson,
    List<Map<String, dynamic>> storesJson = const <Map<String, dynamic>>[],
    List<CatalogImageFile> imageFiles = const <CatalogImageFile>[],
    List<Map<String, dynamic>> stockJson = const <Map<String, dynamic>>[],
  }) {
    final stockByProductId = <int, int>{};
    for (final row in stockJson) {
      final productId = (row['product_id'] as num?)?.toInt() ??
          (row['productId'] as num?)?.toInt();
      final stockValue = (row['stock'] as num?)?.toInt() ??
          (row['quantity'] as num?)?.toInt();
      if (productId != null && stockValue != null) {
        stockByProductId[productId] =
            (stockByProductId[productId] ?? 0) + stockValue;
      }
    }

    // 1. Índice de categorías: id → datos raw
    final categoryIndex = <int, Map<String, dynamic>>{};
    for (final c in categoriesJson) {
      final id = (c['id'] as num?)?.toInt();
      if (id != null) categoryIndex[id] = c;
    }

    // 2. Índice de stores: id → name
    final storeNames = <int, String>{};
    for (final s in storesJson) {
      final id = (s['id'] as num?)?.toInt();
      final name = s['name'] as String?;
      if (id != null && name != null) storeNames[id] = name;
    }

    // 3. Agrupar productos por category_id
    final productsByCatId = <int, List<CatalogProductEntry>>{};
    for (final p in productsJson) {
      final id = (p['id'] as num?)?.toInt();
      final name = p['name'] as String?;
      final sku = p['sku'] as String? ?? '';
      final price = (p['price'] as num?)?.toDouble() ?? 0;
      final fallbackStock = (p['stock'] as num?)?.toInt() ?? 0;
      final stock = stockByProductId[id] ?? fallbackStock;
      final categoryIdRaw = (p['category_id'] as num?)?.toInt();
      final categoryId = categoryIdRaw != null && categoryIndex.containsKey(categoryIdRaw)
          ? categoryIdRaw
          : null;
      final categoryName = categoryId != null
          ? (categoryIndex[categoryId]!['name'] as String? ?? 'Sin categoría')
          : 'Sin categoría';
        final categoryImageUrl = categoryId != null
          ? _categoryImageUrl(categoryIndex[categoryId]!)
          : '';
      final productImageFiles = _imageIds(p['images'])
          .map((imageId) => _findImageById(imageFiles, imageId))
          .whereType<CatalogImageFile>()
          .toList();
      final description = (p['description'] as String?) ?? '';
      if (id == null || name == null) continue;
      productsByCatId
          .putIfAbsent(categoryId ?? -1, () => [])
          .add(
            CatalogProductEntry(
              id: id,
              name: name,
              sku: sku,
              description: description,
              price: price,
              stock: stock,
              categoryId: categoryId,
              categoryName: categoryName,
              categoryImageUrl: categoryImageUrl,
              imageFiles: productImageFiles,
            ),
          );
    }

    // 4. Construir secciones agrupando por storeId
    final sectionMap = <int, List<CatalogCategory>>{};
    for (final entry in categoryIndex.entries) {
      final catId = entry.key;
      final catData = entry.value;
      final catName = catData['name'] as String? ?? 'Categoría $catId';
      final storeId = (catData['store_id'] as num?)?.toInt() ?? 0;
      final storeName = storeNames[storeId] ?? getStoreName(storeId);
      final prods = productsByCatId[catId] ?? const [];
      final imageUrl = _categoryImageUrl(catData);
      final heroImages = _heroImages(prods);
      sectionMap
          .putIfAbsent(storeId, () => [])
          .add(
            CatalogCategory(
              id: catId,
              name: catName,
              storeId: storeId,
              storeName: storeName,
              imageFile: heroImages.isEmpty ? null : heroImages.first,
              imageUrl: imageUrl,
              heroImages: heroImages,
              products: prods,
            ),
          );
    }

    if (productsByCatId.containsKey(-1)) {
      final uncategorizedProducts = productsByCatId[-1] ?? const <CatalogProductEntry>[];
      final heroImages = _heroImages(uncategorizedProducts.toList());
      sectionMap.putIfAbsent(0, () => []).add(
        CatalogCategory(
          id: -1,
          name: 'Sin categoría',
          storeId: 0,
          storeName: 'General',
          imageFile: heroImages.isEmpty ? null : heroImages.first,
          heroImages: heroImages,
          products: uncategorizedProducts.toList(),
        ),
      );
    }

    // Ordenar categorías alfabéticamente dentro de cada sección
    for (final list in sectionMap.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }

    return _toSections(sectionMap, storeNames);
  }

  /// El respaldo histórico guarda IDs separados por coma, mientras que otros
  /// exportadores pueden producir una lista JSON. Aceptamos ambos formatos y
  /// descartamos valores vacíos antes de construir las URLs públicas.
  static Iterable<String> _imageIds(dynamic value) {
    final values = switch (value) {
      String text => text.split(','),
      Iterable<dynamic> items => items.whereType<String>(),
      _ => const <String>[],
    };

    return values.map((id) => id.trim()).where((id) => id.isNotEmpty);
  }

  static String _categoryImageUrl(Map<String, dynamic> category) {
    for (final key in const ['imageUrl', 'image_url', 'coverUrl', 'cover_url']) {
      final value = category[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static List<CatalogSection> _toSections(
    Map<int, List<CatalogCategory>> sectionMap,
    Map<int, String> storeNames,
  ) {
    // storeId 0 (General) al final; el resto en orden ascendente
    final storeIds = sectionMap.keys.toList()
      ..sort((a, b) {
        if (a == 0) return 1;
        if (b == 0) return -1;
        return a.compareTo(b);
      });
    return [
      for (final id in storeIds)
        CatalogSection(
          storeId: id,
          storeName: storeNames[id] ?? sectionMap[id]!.first.storeName,
          categories: sectionMap[id]!,
        ),
    ];
  }

  static CatalogImageFile? _findImageById(
    List<CatalogImageFile> imageFiles,
    String id,
  ) {
    for (final file in imageFiles) {
      if (file.id == id) return file;
    }
    return null;
  }

  static List<CatalogImageFile> _heroImages(
    List<CatalogProductEntry> products,
  ) {
    final seenIds = <String>{};
    return [
      for (final product in products)
        for (final image in product.imageFiles)
          if (seenIds.add(image.id)) image,
    ];
  }

  /// Devuelve la sección correspondiente a un [storeId], o null si no existe.
  static CatalogSection? sectionFor(
    List<CatalogSection> sections,
    int storeId,
  ) {
    for (final s in sections) {
      if (s.storeId == storeId) return s;
    }
    return null;
  }

  /// Devuelve todos los productos de una sección en una lista plana.
  static List<CatalogProductEntry> flatProducts(CatalogSection section) => [
    for (final c in section.categories) ...c.products,
  ];
}

// ── Modelo legado — mantiene compatibilidad de compilación ───────────────────
@Deprecated('Usar CatalogProductEntry + CatalogCategory en su lugar.')
class CatalogItem {
  final String name;
  final String category;
  final double price;
  final String store;
  final String description;
  final String imageUrl;
  final List<String> tags;
  final bool available;

  const CatalogItem({
    required this.name,
    required this.category,
    required this.price,
    required this.store,
    this.description = '',
    this.imageUrl = '',
    this.tags = const [],
    this.available = true,
  });
}
