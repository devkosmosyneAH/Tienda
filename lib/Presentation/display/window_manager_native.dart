import 'package:window_manager/window_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

Future<void> initializeWindowManager() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
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
    await windowManager.setTitle('Sistema de Gestión Comercial – Tienda');

    await Future.delayed(const Duration(milliseconds: 200));
    await windowManager.restore();
    await windowManager.focus();
    return;
  }

  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux)) {
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
    await windowManager.setTitle('Sistema de Gestión Comercial – Tienda');
  }
}
