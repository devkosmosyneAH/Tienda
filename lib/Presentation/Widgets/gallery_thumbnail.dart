import 'package:flutter/material.dart';

/// Miniatura seleccionable, independiente del estado del visor.
class GalleryThumbnail extends StatelessWidget {
  const GalleryThumbnail({
    super.key,
    required this.imageUrl,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  final String imageUrl;
  final int index;
  final bool isSelected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(12));
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Ver imagen ${index + 1}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              onTap: () => onTap(index),
              borderRadius: radius,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 80,
                height: 80,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color:
                        isSelected ? const Color(0xFF4DA3FF) : Colors.white24,
                    width: isSelected ? 3 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color:
                                const Color(0xFF4DA3FF).withValues(alpha: 0.36),
                            blurRadius: 11,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFF242424),
                    child: Icon(Icons.broken_image_outlined,
                        color: Colors.white54),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
