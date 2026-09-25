import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/widgets.dart';

Future<void> initializeWindowManager() async {
  if (kIsWeb) return;

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    await windowManager.waitUntilReadyToShow(null, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    await windowManager.setSize(const Size(800, 600));
    await windowManager.setMinimumSize(const Size(400, 300));
    await windowManager.setResizable(true);
    await windowManager.setMinimizable(true);
    await windowManager.setMaximizable(true);
    await windowManager.setClosable(true);
    await windowManager.setTitle('Sistema de Gestión Comercial – Bazar & Tienda');

    if (Platform.isWindows) {
      await Future.delayed(const Duration(milliseconds: 200));
      await windowManager.restore();
      await windowManager.focus();
    }
  }
}
