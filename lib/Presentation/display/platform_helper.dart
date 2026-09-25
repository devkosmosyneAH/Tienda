import 'package:flutter/foundation.dart';

/// Helpers de plataforma sin usar `dart:io` directamente para evitar romper Web.
bool get isWeb => kIsWeb;

bool get isDesktop {
  if (kIsWeb) return false;
  final p = defaultTargetPlatform;
  return p == TargetPlatform.windows || p == TargetPlatform.macOS || p == TargetPlatform.linux;
}

bool get isMobile {
  if (kIsWeb) return false;
  final p = defaultTargetPlatform;
  return p == TargetPlatform.android || p == TargetPlatform.iOS;
}

bool get isWindows => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
bool get isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
bool get isLinux => !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
