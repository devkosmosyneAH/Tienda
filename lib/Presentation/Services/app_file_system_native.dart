import 'dart:io';

class AppFileSystem {
  const AppFileSystem();

  Future<bool> exists(String path) async => File(path).exists();

  Future<bool> existsSync(String path) => Future.value(File(path).existsSync());

  Future<void> createDirectory(String path) async =>
      Directory(path).create(recursive: true);

  Future<void> delete(String path) async => File(path).delete();

  Future<void> writeBytes(String path, List<int> bytes) async =>
      File(path).writeAsBytes(bytes, flush: true);

  Future<List<int>> readBytes(String path) async => File(path).readAsBytes();

  Future<void> copy(String sourcePath, String destinationPath) async =>
      File(sourcePath).copy(destinationPath);

  String get separator => Platform.pathSeparator;

  Future<String> get temporaryDirectoryPath async =>
      (await Directory.systemTemp.createTemp()).path;
}
