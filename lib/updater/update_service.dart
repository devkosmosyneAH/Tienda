import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:tienda/core/app_config.dart';
import 'package:tienda/core/app_logger.dart';
import 'package:tienda/runtime/ui_runtime.dart';

class UpdateService {
  static Future<bool> checkForUpdates({String? manifestUrl}) async {
    try {
      final manifest = await _fetchManifest(
        manifestUrl ?? AppConfig.updateManifestUrl,
      );
      final installed = await _readInstalledState();
      return shouldApplyUpdate(
        remoteVersion: _manifestVersion(manifest),
        remoteSha: manifest['sha256']?.toString(),
        currentVersion: installed.version,
        currentSha: installed.sha256,
      );
    } catch (error) {
      AppLogger.log('No se pudo comprobar actualizaciones', error: error);
      return false;
    }
  }

  static bool shouldApplyUpdate({
    required int remoteVersion,
    required String? remoteSha,
    required int currentVersion,
    String? currentSha,
  }) {
    if (remoteVersion > currentVersion) return true;
    return remoteVersion == currentVersion &&
        remoteSha != null &&
        remoteSha.isNotEmpty &&
        remoteSha != currentSha;
  }

  static Future<bool> downloadAndApplyUpdate({
    String? manifestUrl,
    String? bundleUrl,
    String? destinationDir,
  }) async {
    Directory? uiDirectory;
    Directory? backupDirectory;
    try {
      final manifest = await _fetchManifest(
        manifestUrl ?? AppConfig.updateManifestUrl,
      );
      final installed = await _readInstalledState();
      final remoteVersion = _manifestVersion(manifest);
      final remoteSha = manifest['sha256']?.toString() ?? '';

      if (!shouldApplyUpdate(
        remoteVersion: remoteVersion,
        remoteSha: remoteSha,
        currentVersion: installed.version,
        currentSha: installed.sha256,
      )) {
        return false;
      }

      final runtimeDirectory = await UiRuntime.runtimeDirectory();
      uiDirectory = destinationDir == null
          ? await UiRuntime.uiDirectory()
          : Directory(destinationDir);
      final stagingDirectory = await UiRuntime.stagingDirectory();
      backupDirectory = await UiRuntime.backupDirectory();
      final bundleFile = File(path.join(runtimeDirectory.path, 'update.zip'));
      final resolvedBundleUrl =
          manifest['bundleUrl']?.toString() ??
          bundleUrl ??
          AppConfig.updateBundleUrl;

      await runtimeDirectory.create(recursive: true);
      await _resetDirectory(stagingDirectory);

      final response = await http
          .get(Uri.parse(resolvedBundleUrl))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != HttpStatus.ok) {
        throw Exception('No se pudo descargar el paquete de actualización');
      }

      final downloadedSha = sha256.convert(response.bodyBytes).toString();
      if (remoteSha.isEmpty || downloadedSha != remoteSha) {
        throw Exception('El hash del paquete no coincide con el manifiesto');
      }
      await bundleFile.writeAsBytes(response.bodyBytes, flush: true);

      await _validateArchive(bundleFile.path);
      await _extractArchive(bundleFile.path, stagingDirectory.path);
      final sourceUiDirectory = _findInterfaceDirectory(stagingDirectory);
      if (sourceUiDirectory == null) {
        throw Exception('No se encontró la interfaz en el paquete de actualización');
      }

      await _replaceInterface(
        source: sourceUiDirectory,
        destination: uiDirectory,
        backup: backupDirectory,
      );
      await _writeInstalledState(
        _InstalledUiState(version: remoteVersion, sha256: remoteSha),
      );

      AppLogger.log(
        'Actualización de interfaz aplicada desde $resolvedBundleUrl',
      );
      return true;
    } catch (error) {
      AppLogger.log('La actualización de interfaz falló', error: error);
      if (uiDirectory != null && backupDirectory != null) {
        await _rollbackInterface(uiDirectory, backupDirectory);
      }
      return false;
    }
  }

  static Future<Map<String, dynamic>> _fetchManifest(String manifestUrl) async {
    final response = await http
        .get(Uri.parse(manifestUrl))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != HttpStatus.ok) {
      throw Exception('No se pudo leer el manifiesto de actualización');
    }
    final manifest = jsonDecode(response.body);
    if (manifest is! Map<String, dynamic>) {
      throw Exception('Manifest inválido');
    }
    return manifest;
  }

  static int _manifestVersion(Map<String, dynamic> manifest) {
    final value = manifest['version'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Future<_InstalledUiState> _readInstalledState() async {
    final stateFile = await UiRuntime.versionStateFile();
    if (!await stateFile.exists()) {
      return const _InstalledUiState(version: AppConfig.appVersion, sha256: '');
    }

    try {
      final decoded = jsonDecode(await stateFile.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Estado inválido');
      }
      return _InstalledUiState(
        version: _manifestVersion(decoded),
        sha256: decoded['sha256']?.toString() ?? '',
      );
    } catch (error) {
      AppLogger.log('No se pudo leer el estado de la interfaz', error: error);
      return const _InstalledUiState(version: AppConfig.appVersion, sha256: '');
    }
  }

  static Future<void> _writeInstalledState(_InstalledUiState state) async {
    final stateFile = await UiRuntime.versionStateFile();
    await stateFile.parent.create(recursive: true);
    await stateFile.writeAsString(
      jsonEncode({'version': state.version, 'sha256': state.sha256}),
      flush: true,
    );
  }

  static Directory? _findInterfaceDirectory(Directory stagingDirectory) {
    final candidates = <Directory>[
      Directory(path.join(stagingDirectory.path, 'ui')),
      Directory(path.join(stagingDirectory.path, 'web')),
      Directory(path.join(stagingDirectory.path, 'build', 'web')),
      Directory(path.join(stagingDirectory.path, 'dist')),
    ];
    return candidates.where((directory) => directory.existsSync()).firstOrNull;
  }

  static Future<void> _validateArchive(String archivePath) async {
    final result = await Process.run('tar', ['-tf', archivePath]);
    if (result.exitCode != 0) {
      throw Exception('No se pudo inspeccionar el paquete de actualización');
    }

    final entries = LineSplitter.split(result.stdout.toString());
    if (entries.isEmpty ||
        entries.any((entry) =>
            entry.startsWith('/') ||
            entry.startsWith('\\') ||
            entry.split('/').contains('..'))) {
      throw Exception('El paquete de actualización contiene rutas no permitidas');
    }
  }

  static Future<void> _extractArchive(
    String archivePath,
    String destinationPath,
  ) async {
    final result = await Process.run('tar', [
      '-xf',
      archivePath,
      '-C',
      destinationPath,
    ]);
    if (result.exitCode != 0) {
      throw Exception('No se pudo descomprimir la actualización');
    }
  }

  static Future<void> _replaceInterface({
    required Directory source,
    required Directory destination,
    required Directory backup,
  }) async {
    await destination.parent.create(recursive: true);
    if (await backup.exists()) {
      await backup.delete(recursive: true);
    }
    if (await destination.exists()) {
      await destination.rename(backup.path);
    }
    await source.rename(destination.path);
  }

  static Future<void> _rollbackInterface(
    Directory destination,
    Directory backup,
  ) async {
    try {
      if (!await backup.exists()) return;
      if (await destination.exists()) {
        await destination.delete(recursive: true);
      }
      await backup.rename(destination.path);
      AppLogger.log('Rollback de interfaz completado');
    } catch (error) {
      AppLogger.log('No se pudo restaurar la interfaz', error: error);
    }
  }

  static Future<void> _resetDirectory(Directory directory) async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);
  }
}

class _InstalledUiState {
  const _InstalledUiState({required this.version, required this.sha256});

  final int version;
  final String sha256;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
