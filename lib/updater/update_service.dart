import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:tienda/core/app_config.dart';
import 'package:tienda/core/app_logger.dart';
import 'package:tienda/Presentation/Services/app_io.dart';

class UpdateService {
  static Future<bool> checkForUpdates({String? manifestUrl}) async {
    try {
      final manifest = await _fetchManifest(
        manifestUrl ?? AppConfig.updateManifestUrl,
      );
      final remoteVersion = (manifest['version'] as num?)?.toInt() ?? 0;
      final remoteSha = manifest['sha256']?.toString() ?? '';
      return shouldApplyUpdate(
        remoteVersion: remoteVersion,
        remoteSha: remoteSha,
        currentVersion: AppConfig.appVersion,
      );
    } catch (e) {
      AppLogger.log('No se pudo comprobar actualizaciones', error: e);
      return false;
    }
  }

  static bool shouldApplyUpdate({
    required int remoteVersion,
    required String? remoteSha,
    required int currentVersion,
    String? currentSha,
  }) {
    if (remoteVersion > currentVersion) {
      return true;
    }
    if (remoteSha != null && remoteSha.isNotEmpty) {
      if (currentSha == null || currentSha.isEmpty) {
        return true;
      }
      return remoteSha != currentSha;
    }
    return false;
  }

  static Future<bool> downloadAndApplyUpdate({
    String? manifestUrl,
    String? bundleUrl,
    String? destinationDir,
  }) async {
    final io = const AppIO();
    final dir = Directory(
      destinationDir ?? path.join(Directory.current.path, 'update_bundle'),
    );
    final bundlePath = path.join(dir.path, 'update.zip');
    final stagingDir = Directory(path.join(dir.path, 'staging'));
    final backupDir = Directory(path.join(dir.path, 'web_backup'));
    final appWebDir = Directory(path.join(Directory.current.path, 'web'));

    try {
      await io.createDirectory(dir.path);
      await io.createDirectory(stagingDir.path);

      final manifest = await _fetchManifest(
        manifestUrl ?? AppConfig.updateManifestUrl,
      );
      final remoteVersion = (manifest['version'] as num?)?.toInt() ?? 0;
      final remoteSha = manifest['sha256']?.toString() ?? '';
      final resolvedBundleUrl =
          manifest['bundleUrl']?.toString() ??
          bundleUrl ??
          AppConfig.updateBundleUrl;

      if (remoteVersion <= AppConfig.appVersion &&
          (remoteSha.isEmpty || remoteSha == _currentHash())) {
        return false;
      }

      final response = await http
          .get(Uri.parse(resolvedBundleUrl))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception('No se pudo descargar el paquete de actualización');
      }

      await io.writeBytes(bundlePath, response.bodyBytes);
      final downloadedSha = sha256.convert(response.bodyBytes).toString();
      if (remoteSha.isNotEmpty && downloadedSha != remoteSha) {
        throw Exception('El hash del paquete no coincide con el manifiesto');
      }

      await _extractArchive(bundlePath, stagingDir.path);
      final sourceUiDir = _findInterfaceDirectory(stagingDir);
      if (sourceUiDir == null) {
        throw Exception(
          'No se encontró la interfaz en el paquete de actualización',
        );
      }

      if (backupDir.existsSync()) {
        await backupDir.delete(recursive: true);
      }
      await _copyDirectoryContents(appWebDir, backupDir);
      await _clearDirectory(appWebDir);
      await _copyDirectoryContents(sourceUiDir, appWebDir);

      AppLogger.log(
        'Actualización aplicada correctamente desde $resolvedBundleUrl',
      );
      return true;
    } catch (e) {
      AppLogger.log('La actualización falló', error: e);
      if (backupDir.existsSync()) {
        try {
          await _clearDirectory(appWebDir);
          await _copyDirectoryContents(backupDir, appWebDir);
        } catch (rollbackError) {
          AppLogger.log(
            'No se pudo restaurar la interfaz',
            error: rollbackError,
          );
        }
      }
      return false;
    }
  }

  static Future<Map<String, dynamic>> _fetchManifest(String manifestUrl) async {
    final response = await http
        .get(Uri.parse(manifestUrl))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('No se pudo leer el manifiesto de actualización');
    }
    final manifest = jsonDecode(response.body);
    if (manifest is! Map<String, dynamic>) {
      throw Exception('Manifest inválido');
    }
    return manifest;
  }

  static String _currentHash() {
    return '';
  }

  static Directory? _findInterfaceDirectory(Directory stagingDir) {
    final candidates = <Directory>[
      Directory(path.join(stagingDir.path, 'web')),
      Directory(path.join(stagingDir.path, 'build', 'web')),
      Directory(path.join(stagingDir.path, 'dist')),
    ];
    return candidates.where((directory) => directory.existsSync()).firstOrNull;
  }

  static Future<void> _extractArchive(
    String archivePath,
    String destinationPath,
  ) async {
    if (Platform.isWindows) {
      final result = await Process.run('tar', [
        '-xf',
        archivePath,
        '-C',
        destinationPath,
      ]);
      if (result.exitCode != 0) {
        throw Exception(result.stderr.toString());
      }
      return;
    }

    final result = await Process.run('unzip', [
      '-o',
      archivePath,
      '-d',
      destinationPath,
    ]);
    if (result.exitCode != 0) {
      throw Exception(result.stderr.toString());
    }
  }

  static Future<void> _copyDirectoryContents(
    Directory source,
    Directory destination,
  ) async {
    if (!source.existsSync()) {
      return;
    }
    await destination.create(recursive: true);
    for (final entity in source.listSync()) {
      final targetPath = path.join(
        destination.path,
        path.basename(entity.path),
      );
      if (entity is File) {
        await entity.copy(targetPath);
      } else if (entity is Directory) {
        await _copyDirectoryContents(entity, Directory(targetPath));
      }
    }
  }

  static Future<void> _clearDirectory(Directory directory) async {
    if (!directory.existsSync()) {
      return;
    }
    for (final entity in directory.listSync()) {
      if (entity is File) {
        await entity.delete();
      } else if (entity is Directory) {
        await entity.delete(recursive: true);
      }
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
