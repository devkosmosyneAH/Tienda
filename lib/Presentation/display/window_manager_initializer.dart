import 'window_manager_native.dart'
    if (dart.library.html) 'window_manager_web.dart' as impl;

Future<void> initializeWindowManager() => impl.initializeWindowManager();
