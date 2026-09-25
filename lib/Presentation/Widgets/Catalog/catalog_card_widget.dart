import 'package:flutter/material.dart';
import 'package:tienda/Presentation/Template/catalog_template.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Widgets/Catalog/catalog_detail_widget.dart';
import 'package:tienda/Presentation/Widgets/drive_image.dart';
import 'package:tienda/Presentation/Widgets/product_gallery_viewer.dart';

/// Card del catálogo con imagen de portada, nombre, descripción y chips de tags.
class CatalogCategoryCard extends StatefulWidget {
  final String name;
  final String storeName;
  final CategoryInfo info;

  const CatalogCategoryCard({
    super.key,
    required this.name,
    required this.storeName,
    required this.info,
  });

  @override
  State<CatalogCategoryCard> createState() => _CatalogCategoryCardState();
}

class _CatalogCategoryCardState extends State<CatalogCategoryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _isHovered = false;

  bool get _isBazar => widget.storeName.toLowerCase() == 'bazar';

  Color get _accentColor =>
      _isBazar ? AppColors.blackOverlay : const Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedScale(
            scale: _isHovered ? 1.02 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: AppColors.whiteOverlay,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _accentColor.withValues(
                      alpha: _isHovered ? 0.16 : 0.08,
                    ),
                    blurRadius: _isHovered ? 24 : 14,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openDetail(context),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CardImage(
                          heroImages: widget.info.heroImages,
                          imageUrl: widget.info.imageUrl,
                          accentColor: _accentColor,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkGray,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${widget.info.products.length} productos',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.mediumGray,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (widget.info.tags.isNotEmpty)
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: widget.info.tags
                                      .take(2)
                                      .map(
                                        (tag) => _TagChip(
                                          label: tag,
                                          color: _accentColor,
                                        ),
                                      )
                                      .toList(),
                                ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 42,
                                child: FilledButton.icon(
                                  onPressed: () => _openDetail(context),
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Ver detalle'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _accentColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SelectionArea(
        child: CatalogDetailWidget(
          name: widget.name,
          storeName: widget.storeName,
          info: widget.info,
        ),
      ),
    );
  }
}

/// Imagen superior de la card con gradiente overlay y badge de la tienda.
class _CardImage extends StatelessWidget {
  final List<CatalogImageFile> heroImages;
  final String imageUrl;
  final Color accentColor;

  const _CardImage({
    required this.heroImages,
    required this.imageUrl,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl.trim().isNotEmpty)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _imageFallback(),
            )
          else if (heroImages.isEmpty)
            _imageFallback()
          else
            PageView.builder(
              itemCount: heroImages.length,
              itemBuilder: (context, index) {
                final image = heroImages[index];
                final imageUrls = heroImages
                    .map((file) => file.thumbnailLink)
                    .toList();
                return Semantics(
                  button: true,
                  label: 'Ampliar imagen ${index + 1} de ${heroImages.length}',
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => ProductGalleryViewer.show(
                        context,
                        images: imageUrls,
                        initialIndex: index,
                      ),
                      child: Hero(
                        tag: ProductGalleryViewer.heroTagFor(
                          image.thumbnailLink,
                        ),
                        child: DriveImage(
                          key: ValueKey(image.id),
                          url: image.thumbnailLink,
                          fit: BoxFit.cover,
                          errorWidget: _imageFallback(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 56,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          if (heroImages.length > 1)
            Positioned(
              right: 10,
              bottom: 10,
              child: _ImageCount(count: heroImages.length),
            ),
        ],
      ),
    );
  }

  Widget _imageFallback() => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [accentColor, accentColor.withValues(alpha: 0.76)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      color: accentColor.withValues(alpha: 0.95),
    ),
    child: const Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Colors.white70,
        size: 40,
      ),
    ),
  );
}

class _ImageCount extends StatelessWidget {
  final int count;

  const _ImageCount({required this.count});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.collections_outlined,
              size: 12,
              color: Colors.white,
            ),
            const SizedBox(width: 3),
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip pequeño de etiqueta.
class _TagChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TagChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
