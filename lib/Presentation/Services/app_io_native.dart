import 'dart:io';

typedef AppFile = File;
typedef AppDirectory = Directory;

class AppIO {
  const AppIO();

  String get pathSeparator => Platform.pathSeparator;

  Future<bool> fileExists(String path) async => File(path).exists();

  Future<void> createDirectory(String path) async =>
      Directory(path).create(recursive: true);

  bool fileExistsSync(String path) => File(path).existsSync();

  Future<void> writeBytes(String path, List<int> bytes) async =>
      File(path).writeAsBytes(bytes, flush: true);

  Future<List<int>> readBytes(String path) async => File(path).readAsBytes();

  Future<void> deleteFile(String path) async => File(path).delete();

  Future<void> copyFile(String sourcePath, String destinationPath) async =>
      File(sourcePath).copy(destinationPath);
}
