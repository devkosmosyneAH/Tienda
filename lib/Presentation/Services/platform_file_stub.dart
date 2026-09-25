class File {
  final String path;
  File(this.path);
  Future<bool> exists() async => false;
  Future<List<int>> readAsBytes() async => <int>[];
  Future<void> writeAsBytes(List<int> bytes, {bool flush = false}) async {}
  Future<void> delete() async {}
}
