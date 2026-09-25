import 'package:flutter/foundation.dart';

Future<void> initializeWindowManager() async {
  // No-op en Web: `window_manager` no está disponible en navegador.
  if (kIsWeb) return;
}
