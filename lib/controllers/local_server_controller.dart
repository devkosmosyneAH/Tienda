import 'package:flutter/foundation.dart';
import 'package:tienda/core/platform_runtime.dart';
import 'package:tienda/server/local_server.dart';
import 'package:tienda/core/app_logger.dart';

class LocalServerController extends ChangeNotifier {
  LocalServerController() {
    initialize();
  }

  bool _isStarted = false;
  bool get isStarted => _isStarted;

  Future<void> initialize() async {
    if (!AppPlatform.isDesktop) {
      return;
    }
    try {
      await LocalServerHost.start();
      _isStarted = LocalServerHost.isRunning;
      notifyListeners();
    } catch (e) {
      AppLogger.log('No se pudo iniciar el servidor local', error: e);
    }
  }
}
