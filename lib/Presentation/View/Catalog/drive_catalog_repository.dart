import 'package:tienda/Presentation/Services/drive_data_service.dart';

/// Repositorio encargado de leer el catálogo público desde Drive.
///
/// Separamos esta responsabilidad para mantener el acceso a los datos de la
/// lógica de navegación y cache en memoria.
class DriveCatalogRepository {
  const DriveCatalogRepository();

  Future<CatalogDriveData> fetchPublicCatalog() {
    return DriveDataService.fetchPublic();
  }
}
