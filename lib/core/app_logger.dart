import 'package:flutter/foundation.dart';

class AppLogger {
  static void log(String message, {Object? error}) {
    debugPrint('[Tienda] $message${error != null ? ' :: $error' : ''}');
  }
}
