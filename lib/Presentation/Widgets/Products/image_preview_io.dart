import 'dart:io';

import 'package:flutter/material.dart';

bool isLocalImagePath(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return false;
  }
  return trimmed.startsWith('file:') ||
      trimmed.contains('/') ||
      trimmed.contains('\\');
}

Widget imagePreview(
  String value, {
  required double width,
  required double height,
  BoxFit fit = BoxFit.cover,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return const SizedBox();
  }

  return isLocalImagePath(trimmed)
      ? Image.file(
          File(trimmed),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: errorBuilder,
        )
      : Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
        );
}
