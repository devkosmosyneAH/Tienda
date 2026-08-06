import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:tienda/core/app_config.dart';
import 'package:tienda/core/app_logger.dart';
import 'package:tienda/Presentation/Services/app_io.dart';

class UpdateService {
  static Future<bool> checkForUpdates({String? manifestUrl}) async {
    try {
      final uri = Uri.parse(manifestUrl ?? AppConfig.updateManifestUrl);
      final response = await http.get(uri);
      if (response.statusCode != 200) return false;
      final manifest = jsonDecode(response.body) as Map<String, dynamic>;
      final remoteVersion = (manifest['version'] as num).toInt();
      final remoteSha = manifest['sha256']?.toString() ?? '';
      final currentVersion = AppConfig.appVersion;
      return remoteVersion > currentVersion || remoteSha.isNotEmpty;
    } catch (e) {
      AppLogger.log('No se pudo comprobar actualizaciones', error: e);
      return false;
    }
  }

  static Future<bool> downloadAndApplyUpdate({
    String? bundleUrl,
    String? destinationDir,
  }) async {
    try {
      final dir =
          destinationDir ?? path.join(Directory.current.path, 'update_bundle');
      final bundlePath = path.join(dir, 'update.zip');
      await AppIO().createDirectory(dir);
      final response = await http.get(
        Uri.parse(bundleUrl ?? AppConfig.updateBundleUrl),
      );
      if (response.statusCode != 200) {
        throw Exception('No se pudo descargar el paquete de actualización');
      }
      await AppIO().writeBytes(bundlePath, response.bodyBytes);
      return true;
    } catch (e) {
      AppLogger.log('La actualización falló', error: e);
      return false;
    }
  }
}
