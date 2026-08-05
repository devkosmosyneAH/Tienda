import 'package:path/path.dart';

import 'database_location_service.dart';
import 'app_io.dart';

/// Servicio para guardar y borrar imágenes junto a la base de datos.
class ImageStorageService {
  static const _imagesFolderName = 'images';

  /// Copia una imagen existente en la carpeta `images` junto a la base de datos.
  /// Devuelve la ruta absoluta del archivo guardado.
  static Future<String> saveImageFile(String sourcePath) async {
    final sourceFile = AppIO();
    if (!await sourceFile.fileExists(sourcePath)) {
      throw Exception('El archivo de imagen no existe: $sourcePath');
    }

    final dbPath = await DatabaseLocationService.getDatabasePath();
    final imagesDir = join(dirname(dbPath), _imagesFolderName);
    await AppIO().createDirectory(imagesDir);

    final fileName = '${DateTime.now().microsecondsSinceEpoch}_${basename(sourcePath)}';
    final destinationPath = join(imagesDir, fileName);

    await sourceFile.copyFile(sourcePath, destinationPath);
    return destinationPath;
  }

  /// Elimina una imagen local almacenada.
  /// Retorna true si el archivo existía y fue borrado.
  static Future<bool> deleteImage(String path) async {
    if (path.trim().isEmpty) return false;

    final file = AppIO();
    if (!await file.fileExists(path)) return false;

    try {
      await file.deleteFile(path);
      return true;
    } catch (_) {
      return false;
    }
  }
}
