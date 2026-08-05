import 'package:flutter/foundation.dart';

/// Helpers de plataforma orientados a entornos locales (no Web).
bool get isWeb => false;

bool get isDesktop {
  final p = defaultTargetPlatform;
  return p == TargetPlatform.windows || p == TargetPlatform.macOS || p == TargetPlatform.linux;
}

bool get isMobile {
  final p = defaultTargetPlatform;
  return p == TargetPlatform.android || p == TargetPlatform.iOS;
}

bool get isWindows => defaultTargetPlatform == TargetPlatform.windows;
bool get isMacOS => defaultTargetPlatform == TargetPlatform.macOS;
bool get isLinux => defaultTargetPlatform == TargetPlatform.linux;
bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;
bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;
