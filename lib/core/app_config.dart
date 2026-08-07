class AppConfig {
  static const String serverHost = '127.0.0.1';
  static const int serverPort = 8080;
  static const String serverBaseUrl = 'http://127.0.0.1:8080';
  static const String localUiUrl = '$serverBaseUrl/';
  static const String updateBaseUrl = String.fromEnvironment(
    'UPDATE_BASE_URL',
    defaultValue: 'https://devkosmosyneah.github.io/PlatformWebTienda',
  );
  static const String updateManifestUrl =
      '$updateBaseUrl/manifest.json';
  static const String updateBundleUrl =
      '$updateBaseUrl/update.zip';
  static const int appVersion = 1;
  static const bool localServerEnabled = true;
}
