class AppFileSystem {
  const AppFileSystem();

  Future<bool> exists(String path) async => false;

  Future<bool> existsSync(String path) async => false;

  Future<void> createDirectory(String path) async {}

  Future<void> delete(String path) async {}

  Future<void> writeBytes(String path, List<int> bytes) async {}

  Future<List<int>> readBytes(String path) async => const [];

  Future<void> copy(String sourcePath, String destinationPath) async {}

  String get separator => '/';

  Future<String> get temporaryDirectoryPath async => '/';
}
