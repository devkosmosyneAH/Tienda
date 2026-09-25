import 'package:flutter/material.dart';

/// Implementación de [DriveImage] para plataformas que usan el pipeline nativo
/// de imágenes de Flutter.
class DriveImage extends StatelessWidget {
  const DriveImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: errorWidget ?? placeholder ?? const SizedBox.shrink(),
      );
    }

    final image = Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) => errorWidget ?? const SizedBox.shrink(),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null || placeholder == null) {
          return child;
        }
        return placeholder!;
      },
    );

    return borderRadius == null
        ? image
        : ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
