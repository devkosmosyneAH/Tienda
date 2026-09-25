import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'database_config.dart';

/// Servicio para detectar automáticamente la ubicación de la base de datos
/// según el sistema operativo y el contexto de ejecución (desarrollo vs ejecutable)
class DatabaseLocationService {
  static const String _databaseName = DatabaseConfig.dbName;

  /// Obtener la ruta de la base de datos según el sistema operativo
  static Future<String> getDatabasePath() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'La base de datos SQLite no es compatible con Flutter Web',
      );
    }

    if (Platform.isWindows) {
      return await _getWindowsDatabasePath();
    } else if (Platform.isMacOS) {
      return await _getMacOSDatabasePath();
    } else if (Platform.isLinux) {
      return await _getLinuxDatabasePath();
    } else if (Platform.isAndroid || Platform.isIOS) {
      return await _getMobileDatabasePath();
    } else {
      throw UnsupportedError(
        'Sistema operativo no soportado: ${Platform.operatingSystem}',
      );
    }
  }

  /// Obtener la ruta específica para Windows
  static Future<String> _getWindowsDatabasePath() async {
    try {
      // Verificar si estamos en un ejecutable o en desarrollo
      if (await _isRunningFromExecutable()) {
        // Ejecutable: usar directorio junto al .exe
        final executableDir = await _getExecutableDirectory();
        final dbPath = join(executableDir, 'bazarnicole', _databaseName);
        return dbPath;
      } else {
        // Desarrollo: usar directorio de SQLite estándar
        final dbPath = join(await getDatabasesPath(), _databaseName);
        return dbPath;
      }
    } catch (e) {
      final fallbackPath = join(await getDatabasesPath(), _databaseName);
      return fallbackPath;
    }
  }

  /// Obtener la ruta específica para macOS
  static Future<String> _getMacOSDatabasePath() async {
    try {
      // En modo debug, siempre usar el directorio estándar de SQLite
      if (kDebugMode) {
        final dbPath = join(await getDatabasesPath(), _databaseName);
        return dbPath;
      }

      // En release mode, verificar si estamos en un .app bundle
      if (await _isRunningFromAppBundle()) {
        // App bundle: usar Contents/Resources/data/
        final appBundleDir = await _getAppBundleDirectory();
        final dbPath = join(
          appBundleDir,
          'Contents',
          'Resources',
          'bazarnicole',
          _databaseName,
        );
        return dbPath;
      } else {
        // Desarrollo: usar directorio de SQLite estándar
        final dbPath = join(await getDatabasesPath(), _databaseName);
        return dbPath;
      }
    } catch (e) {
      return join(await getDatabasesPath(), _databaseName);
    }
  }

  /// Obtener la ruta específica para Linux
  static Future<String> _getLinuxDatabasePath() async {
    try {
      if (await _isRunningFromExecutable()) {
        // Ejecutable: usar directorio junto al binario
        final executableDir = await _getExecutableDirectory();
        final dbPath = join(executableDir, 'bazarnicole', _databaseName);
        return dbPath;
      } else {
        // Desarrollo: usar directorio de SQLite estándar
        final dbPath = join(await getDatabasesPath(), _databaseName);
        return dbPath;
      }
    } catch (e) {
      return join(await getDatabasesPath(), _databaseName);
    }
  }

  /// Obtener la ruta para dispositivos móviles (Android/iOS)
  static Future<String> _getMobileDatabasePath() async {
    final dbPath = join(await getDatabasesPath(), _databaseName);
    return dbPath;
  }

  /// Verificar si estamos ejecutando desde un ejecutable compilado
  static Future<bool> _isRunningFromExecutable() async {
    try {
      final executablePath = Platform.resolvedExecutable;

      // En desarrollo, el ejecutable suele ser dart.exe o flutter
      final executableName = basename(executablePath).toLowerCase();

      // Si contiene dart, flutter, o está en una ruta de desarrollo, es desarrollo
      if (executableName.contains('dart') ||
          executableName.contains('flutter') ||
          executablePath.contains('cache') ||
          executablePath.contains('.pub-cache') ||
          executablePath.contains('bin/cache')) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Verificar si estamos ejecutando desde un app bundle de macOS
  static Future<bool> _isRunningFromAppBundle() async {
    try {
      final executablePath = Platform.resolvedExecutable;
      return executablePath.contains('.app/Contents/MacOS/');
    } catch (e) {
      return false;
    }
  }

  /// Obtener el directorio del ejecutable
  static Future<String> _getExecutableDirectory() async {
    final executablePath = Platform.resolvedExecutable;
    final executableDir = dirname(executablePath);
    return executableDir;
  }

  /// Obtener el directorio del app bundle de macOS
  static Future<String> _getAppBundleDirectory() async {
    final executablePath = Platform.resolvedExecutable;
    // Extraer la ruta hasta .app
    final appIndex = executablePath.indexOf('.app');
    if (appIndex != -1) {
      final appBundleDir = executablePath.substring(0, appIndex + 4);
      return appBundleDir;
    }
    throw Exception('No se pudo determinar el directorio del app bundle');
  }

  /// Crear el directorio de la base de datos si no existe
  static Future<void> ensureDatabaseDirectoryExists(String dbPath) async {
    final dir = Directory(dirname(dbPath));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Obtener información del sistema para debugging
  static Map<String, dynamic> getSystemInfo() {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'executable': Platform.resolvedExecutable,
      'isDebugMode': kDebugMode,
      'isProfileMode': kProfileMode,
      'isReleaseMode': kReleaseMode,
    };
  }

  /// Obtener una ruta fallback estándar para la base de datos
  static Future<String> getFallbackPath() async {
    final dbPath = join(await getDatabasesPath(), _databaseName);
    return dbPath;
  }

  /// Verificar si la base de datos existe en la ruta especificada
  static Future<bool> databaseExists(String path) async {
    final exists = await File(path).exists();
    return exists;
  }

  /// Obtener el tamaño de la base de datos
  static Future<double> getDatabaseSize(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final sizeInBytes = await file.length();
        final sizeInMB = sizeInBytes / (1024 * 1024);
        return sizeInMB;
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }
}
