class AppIO {
  const AppIO();

  String get pathSeparator => '/';

  Future<bool> fileExists(String path) async => false;

  Future<void> createDirectory(String path) async {}

  bool fileExistsSync(String path) => false;

  Future<void> writeBytes(String path, List<int> bytes) async {}

  Future<List<int>> readBytes(String path) async => const [];

  Future<void> deleteFile(String path) async {}

  Future<void> copyFile(String sourcePath, String destinationPath) async {}
}
