class AppFile {
  const AppFile();

  Future<bool> exists(String path) async => false;

  Future<void> writeAsBytes(String path, List<int> bytes) async {}

  Future<void> delete(String path) async {}

  Future<void> copy(String sourcePath, String destinationPath) async {}
}
