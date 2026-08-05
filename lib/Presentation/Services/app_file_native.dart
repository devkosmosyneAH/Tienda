import 'dart:io';

class AppFile {
  const AppFile();

  Future<bool> exists(String path) async => File(path).exists();

  Future<void> writeAsBytes(String path, List<int> bytes) async =>
      File(path).writeAsBytes(bytes, flush: true);

  Future<void> delete(String path) async => File(path).delete();

  Future<void> copy(String sourcePath, String destinationPath) async =>
      File(sourcePath).copy(destinationPath);
}
