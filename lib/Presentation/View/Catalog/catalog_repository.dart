import 'package:tienda/Presentation/Services/drive_data_service.dart';
import 'package:tienda/Presentation/Template/catalog_template.dart';
import 'drive_catalog_repository.dart';

/// Contenedor de datos del catálogo optimizado para búsqueda rápida.
class CatalogRepository {
  final DriveCatalogRepository driveRepository;

  const CatalogRepository({required this.driveRepository});

  Future<CatalogRepositoryData> loadCatalog() async {
    final driveData = await driveRepository.fetchPublicCatalog();

    return CatalogRepositoryData(
      driveData: driveData,
      skuIndex: _buildSkuIndex(driveData.sections),
      categoryIndex: _buildCategoryIndex(driveData.sections),
      storeIndex: _buildStoreIndex(driveData.sections),
    );
  }

  static Map<String, CatalogProductEntry> _buildSkuIndex(
    List<CatalogSection> sections,
  ) {
    final result = <String, CatalogProductEntry>{};
    for (final section in sections) {
      for (final category in section.categories) {
        for (final product in category.products) {
          final sku = product.sku.trim();
          if (sku.isNotEmpty) {
            result[sku.toLowerCase()] = product;
          }
          result[product.id.toString()] = product;
        }
      }
    }
    return result;
  }

  static Map<String, CatalogCategory> _buildCategoryIndex(
    List<CatalogSection> sections,
  ) {
    final result = <String, CatalogCategory>{};
    for (final section in sections) {
      for (final category in section.categories) {
        result[category.id.toString()] = category;
      }
    }
    return result;
  }

  static Map<String, CatalogSection> _buildStoreIndex(
    List<CatalogSection> sections,
  ) {
    final result = <String, CatalogSection>{};
    for (final section in sections) {
      result[section.storeId.toString()] = section;
    }
    return result;
  }
}

/// Datos construidos por [CatalogRepository] y listos para consulta.
class CatalogRepositoryData {
  final CatalogDriveData driveData;
  final Map<String, CatalogProductEntry> skuIndex;
  final Map<String, CatalogCategory> categoryIndex;
  final Map<String, CatalogSection> storeIndex;

  const CatalogRepositoryData({
    required this.driveData,
    required this.skuIndex,
    required this.categoryIndex,
    required this.storeIndex,
  });
}
