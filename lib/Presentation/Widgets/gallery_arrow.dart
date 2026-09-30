import 'package:flutter/material.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';

/// Botón de navegación lateral para [ProductGalleryViewer].
class GalleryArrow extends StatefulWidget {
  const GalleryArrow({
    super.key,
    required this.onPressed,
    required this.isPrevious,
  });

  final VoidCallback onPressed;
  final bool isPrevious;

  @override
  State<GalleryArrow> createState() => _GalleryArrowState();
}

class _GalleryArrowState extends State<GalleryArrow> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final background = _isHovering
        ? AppColors.cream.withValues(alpha: 0.28)
        : AppColors.plumGray42;

    return Semantics(
      button: true,
      label: widget.isPrevious ? 'Imagen anterior' : 'Imagen siguiente',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            boxShadow: _isHovering
                ? [
                    BoxShadow(
                      color: AppColors.plumGray28,
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: IconButton(
            tooltip: widget.isPrevious ? 'Anterior' : 'Siguiente',
            onPressed: widget.onPressed,
            iconSize: 34,
            padding: const EdgeInsets.all(13),
            color: AppColors.cream,
            icon: Icon(
              widget.isPrevious
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
            ),
          ),
        ),
      ),
    );
  }
}
