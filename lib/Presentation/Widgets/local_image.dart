import 'dart:io';

import 'package:flutter/material.dart';

class LocalImage extends StatelessWidget {
  final String? imagePath;
  final BoxFit fit;
  final double? width;
  final double? height;

  const LocalImage({Key? key, this.imagePath, this.fit = BoxFit.cover, this.width, this.height}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (imagePath == null || imagePath!.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Icon(Icons.image_not_supported),
      );
    }

    final file = File(imagePath!);
    if (!file.existsSync()) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Icon(Icons.broken_image),
      );
    }

    return Image.file(
      file,
      fit: fit,
      width: width,
      height: height,
    );
  }
}
