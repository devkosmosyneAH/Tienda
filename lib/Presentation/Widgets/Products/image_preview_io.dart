import 'dart:io';

import 'package:tienda/Presentation/Services/google_drive_backup_service.dart';
import 'package:flutter/material.dart';

bool isLocalImagePath(String value) =>
    value.contains('/') || value.contains('\\') || value.startsWith('file:');

Widget imagePreview(
  String value, {
  required double width,
  required double height,
  BoxFit fit = BoxFit.cover,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) {
  return isLocalImagePath(value)
      ? Image.file(
          File(value),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: errorBuilder,
        )
      : Image.network(
          GoogleDriveBackupService.publicImageUrl(value.trim()),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: errorBuilder,
        );
}
