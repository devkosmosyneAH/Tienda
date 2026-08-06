import 'package:tienda/core/app_config.dart';

/// Punto de entrada estable para el host de la UI Web local.
/// El launcher visual se conectará a esta URL al activar la migración de UI.
class LocalUiLauncher {
  const LocalUiLauncher();

  Uri get launchUri => Uri.parse(AppConfig.localUiUrl);
}
