import 'package:flutter/material.dart';

/// Botón de cierre consistente para el visor de galería.
class GalleryCloseButton extends StatelessWidget {
  const GalleryCloseButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cerrar visor de imágenes',
      child: Tooltip(
        message: 'Cerrar (Esc)',
        child: Material(
          color: Colors.black.withValues(alpha: 0.36),
          shape: const CircleBorder(),
          child: IconButton(
            onPressed: onPressed,
            icon: const Icon(Icons.close_rounded),
            iconSize: 31,
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            mouseCursor: SystemMouseCursors.click,
          ),
        ),
      ),
    );
  }
}
