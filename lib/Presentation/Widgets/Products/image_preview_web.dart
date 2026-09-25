import 'package:tienda/Presentation/Services/google_drive_backup_service.dart';
import 'package:flutter/material.dart';

Widget imagePreview(
  String value, {
  required double width,
  required double height,
  BoxFit fit = BoxFit.cover,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) {
  final imageId = value.trim();
  if (imageId.isEmpty) {
    return const SizedBox();
  }

  return Image.network(
    GoogleDriveBackupService.publicImageUrl(imageId),
    width: width,
    height: height,
    fit: fit,
    errorBuilder: errorBuilder,
  );
}
