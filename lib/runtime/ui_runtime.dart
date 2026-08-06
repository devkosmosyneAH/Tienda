import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Ubicaciones locales que pertenecen exclusivamente al runtime de la UI.
/// La base de datos, imágenes y configuración del POS permanecen fuera de aquí.
class UiRuntime {
  static const _runtimeDirectoryName = 'tienda_runtime';
  static const _uiDirectoryName = 'ui';
  static const _stagingDirectoryName = 'ui_staging';
  static const _backupDirectoryName = 'ui_backup';
  static const _stateFileName = 'ui_version.json';

  static Future<Directory> runtimeDirectory() async {
    final supportDirectory = await getApplicationSupportDirectory();
    return Directory(path.join(supportDirectory.path, _runtimeDirectoryName));
  }

  static Future<Directory> uiDirectory() async {
    final runtime = await runtimeDirectory();
    return Directory(path.join(runtime.path, _uiDirectoryName));
  }

  static Future<Directory> stagingDirectory() async {
    final runtime = await runtimeDirectory();
    return Directory(path.join(runtime.path, _stagingDirectoryName));
  }

  static Future<Directory> backupDirectory() async {
    final runtime = await runtimeDirectory();
    return Directory(path.join(runtime.path, _backupDirectoryName));
  }

  static Future<File> versionStateFile() async {
    final runtime = await runtimeDirectory();
    return File(path.join(runtime.path, _stateFileName));
  }
}
