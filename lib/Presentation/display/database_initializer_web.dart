import 'package:flutter/foundation.dart';

/// Implementación Web (vacía) para la inicialización de base de datos.
///
/// Por ahora no hacemos nada en Web — mantenemos la puerta abierta para
/// una futura integración con Drift/wasm o `sql.js` sin tocar la base
/// de código existente para mobile/desktop.
Future<void> initializeDatabasePlatform() async {
  // No-op en Web. Aquí se puede inicializar Drift WASM más adelante.
  if (kIsWeb) return;
}
