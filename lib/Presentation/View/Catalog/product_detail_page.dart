import 'dart:ui';

import 'package:tienda/Presentation/Template/catalog_template.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Widgets/drive_image.dart';
import 'package:tienda/Presentation/Widgets/product_gallery_viewer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tienda/Presentation/Utils/web_nav.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.product, this.deepLinkSku});

  factory ProductDetailPage.fromSku({Key? key, required String sku}) {
    return ProductDetailPage(
      key: key,
      product: CatalogProductEntry(
        id: -1,
        name: 'Producto',
        sku: sku,
        categoryName: 'Sin categoría',
      ),
      deepLinkSku: sku,
    );
  }

  final CatalogProductEntry product;
  final String? deepLinkSku;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late final ScrollController _scrollController;
  int _selectedImageIndex = 0;
  bool _showHero = false;
  bool _showContent = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _showHero = true;
        _showContent = true;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1000;
    final isDesktop = screenWidth >= 1000;

    final heroImages = widget.product.imageFiles.isEmpty
        ? const <CatalogImageFile>[]
        : widget.product.imageFiles;
    final heroImage = heroImages.isEmpty ? null : heroImages.first;
    final accentColor =
        widget.product.categoryName.toLowerCase().contains('bazar')
        ? AppColors.blackOverlay
        : const Color(0xFF2E7D32);

    final images = heroImages;
    final currentImage = images.isEmpty
        ? heroImage
        : images[_selectedImageIndex.clamp(0, images.length - 1)];

    final stockLabel = widget.product.stock > 0 ? 'Disponible' : 'Sin stock';
    final stockColor = widget.product.stock > 0
        ? accentColor
        : AppColors.mediumGray;
    final heroHeight = isDesktop
        ? 420.0
        : isTablet
        ? 320.0
        : 240.0;
    final productName = widget.product.name.isEmpty
        ? 'Producto destacado'
        : widget.product.name;
    final categoryLabel = widget.product.categoryName.isEmpty
        ? 'Catálogo'
        : widget.product.categoryName;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: heroHeight + 28,
            pinned: true,
            floating: false,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            forceMaterialTransparency: true,
            automaticallyImplyLeading: false,
            elevation: 0,
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final scrollOffset = _scrollController.hasClients
                    ? _scrollController.offset
                    : 0.0;
                final progress = (scrollOffset / (heroHeight + 28)).clamp(
                  0.0,
                  1.0,
                );
                final overlayOpacity = 0.12 + progress * 0.38;
                final blurValue = 4.0 + progress * 10.0;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _HeroSection(
                      heroImage: currentImage,
                      categoryImageUrl: widget.product.categoryImageUrl,
                      accentColor: accentColor,
                      product: widget.product,
                      heroHeight: heroHeight,
                      onImageTap: () => ProductGalleryViewer.show(
                        context,
                        images: images
                            .map((image) => image.thumbnailLink)
                            .toList(),
                        initialIndex: _selectedImageIndex,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 118 + MediaQuery.of(context).padding.top,
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: blurValue,
                            sigmaY: blurValue,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: overlayOpacity,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 16,
                      child: _RoundBackButton(
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            if (kIsWeb) {
                              navigateToExternalCatalog(
                                'https://bazarypapelerianicole.github.io/bazarproject/#/catalog',
                              );
                            } else {
                              Navigator.pushReplacementNamed(
                                context,
                                '/catalog',
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1300),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile
                        ? 16
                        : isTablet
                        ? 24
                        : 32,
                    isMobile ? 20 : 28,
                    isMobile
                        ? 16
                        : isTablet
                        ? 24
                        : 32,
                    32,
                  ),
                  child: isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 55,
                              child: AnimatedOpacity(
                                opacity: _showHero ? 1 : 0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                child: AnimatedScale(
                                  scale: _showHero ? 1 : 0.96,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  child: _ProductMediaCard(
                                    heroImage: currentImage,
                                    images: images,
                                    accentColor: accentColor,
                                    selectedIndex: _selectedImageIndex,
                                    onSelectImage: (index) => setState(() {
                                      _selectedImageIndex = index;
                                    }),
                                    onOpenGallery: () =>
                                        ProductGalleryViewer.show(
                                          context,
                                          images: images
                                              .map(
                                                (image) => image.thumbnailLink,
                                              )
                                              .toList(),
                                          initialIndex: _selectedImageIndex,
                                        ),
                                    product: widget.product,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 32),
                            Expanded(
                              flex: 45,
                              child: AnimatedSlide(
                                offset: _showContent
                                    ? Offset.zero
                                    : const Offset(0, 0.04),
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                child: AnimatedOpacity(
                                  opacity: _showContent ? 1 : 0,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  child: _DetailPanel(
                                    product: widget.product,
                                    accentColor: accentColor,
                                    stockLabel: stockLabel,
                                    stockColor: stockColor,
                                    showContent: _showContent,
                                    productName: productName,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedOpacity(
                              opacity: _showHero ? 1 : 0,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              child: AnimatedScale(
                                scale: _showHero ? 1 : 0.96,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                child: _ProductMediaCard(
                                  heroImage: currentImage,
                                  images: images,
                                  accentColor: accentColor,
                                  selectedIndex: _selectedImageIndex,
                                  onSelectImage: (index) => setState(() {
                                    _selectedImageIndex = index;
                                  }),
                                  onOpenGallery: () =>
                                      ProductGalleryViewer.show(
                                        context,
                                        images: images
                                            .map((image) => image.thumbnailLink)
                                            .toList(),
                                        initialIndex: _selectedImageIndex,
                                      ),
                                  product: widget.product,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            AnimatedSlide(
                              offset: _showContent
                                  ? Offset.zero
                                  : const Offset(0, 0.04),
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              child: AnimatedOpacity(
                                opacity: _showContent ? 1 : 0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                child: _DetailPanel(
                                  product: widget.product,
                                  accentColor: accentColor,
                                  stockLabel: stockLabel,
                                  stockColor: stockColor,
                                  showContent: _showContent,
                                  productName: productName,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.heroImage,
    required this.categoryImageUrl,
    required this.accentColor,
    required this.product,
    required this.heroHeight,
    required this.onImageTap,
  });

  final CatalogImageFile? heroImage;
  final String categoryImageUrl;
  final Color accentColor;
  final CatalogProductEntry product;
  final double heroHeight;
  final VoidCallback onImageTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = heroImage?.thumbnailLink ?? '';
    final hasCategoryCover = categoryImageUrl.trim().isNotEmpty;
    final cover = hasCategoryCover
        ? Image.network(
            categoryImageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackDecoration(accentColor),
          )
        : imageUrl.isNotEmpty
        ? DriveImage(
            url: imageUrl,
            fit: BoxFit.cover,
            errorWidget: _fallbackDecoration(accentColor),
          )
        : _fallbackDecoration(accentColor);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasCategoryCover)
          Semantics(
            label: 'Portada de la categoría ${product.categoryName}',
            child: cover,
          )
        else if (imageUrl.isNotEmpty)
          Semantics(
            button: true,
            label: 'Ampliar imágenes de ${product.name}',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onImageTap,
                child: Hero(
                  tag: ProductGalleryViewer.heroTagFor(imageUrl),
                  child: cover,
                ),
              ),
            ),
          )
        else
          cover,
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: heroHeight * 0.7,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.44),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductMediaCard extends StatelessWidget {
  const _ProductMediaCard({
    required this.heroImage,
    required this.images,
    required this.accentColor,
    required this.selectedIndex,
    required this.onSelectImage,
    required this.onOpenGallery,
    required this.product,
  });

  final CatalogImageFile? heroImage;
  final List<CatalogImageFile> images;
  final Color accentColor;
  final int selectedIndex;
  final ValueChanged<int> onSelectImage;
  final VoidCallback onOpenGallery;
  final CatalogProductEntry product;

  @override
  Widget build(BuildContext context) {
    final imageUrl = heroImage?.thumbnailLink ?? '';
    final hasMultipleImages = images.length > 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Semantics(
                button: true,
                label: 'Ampliar imágenes de ${product.name}',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onOpenGallery,
                    child: Hero(
                      tag: imageUrl.isNotEmpty
                          ? ProductGalleryViewer.heroTagFor(imageUrl)
                          : const ValueKey('hero-fallback'),
                      child: imageUrl.isNotEmpty
                          ? DriveImage(
                              url: imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: _fallbackDecoration(accentColor),
                            )
                          : _fallbackDecoration(accentColor),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (hasMultipleImages) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(images.length, (index) {
                final image = images[index];
                final isSelected = index == selectedIndex;
                return GestureDetector(
                  onTap: () => onSelectImage(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? accentColor.withValues(alpha: 0.6)
                            : Colors.transparent,
                        width: isSelected ? 2 : 0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: image.thumbnailLink.isNotEmpty
                          ? DriveImage(
                              url: image.thumbnailLink,
                              fit: BoxFit.cover,
                              errorWidget: _fallbackDecoration(accentColor),
                            )
                          : _fallbackDecoration(accentColor),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.product,
    required this.accentColor,
    required this.stockLabel,
    required this.stockColor,
    required this.showContent,
    required this.productName,
  });

  final CatalogProductEntry product;
  final Color accentColor;
  final String stockLabel;
  final Color stockColor;
  final bool showContent;
  final String productName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final infoItems = <_DetailItem>[
      _DetailItem(
        icon: Icons.qr_code_2_rounded,
        title: 'SKU',
        value: product.sku.isEmpty ? product.id.toString() : product.sku,
      ),
      _DetailItem(
        icon: Icons.category_outlined,
        title: 'Categoría',
        value: product.categoryName.isEmpty
            ? 'Sin categoría'
            : product.categoryName,
      ),
      _DetailItem(
        icon: Icons.inventory_2_outlined,
        title: 'Stock',
        value: product.stock > 0 ? '${product.stock} unidades' : 'Sin unidades',
      ),
      _DetailItem(
        icon: Icons.attach_money_rounded,
        title: 'Precio',
        value: '\$${product.price.toStringAsFixed(2)}',
      ),
      _DetailItem(
        icon: Icons.storefront_outlined,
        title: 'Tienda',
        value: product.categoryName.isEmpty
            ? 'Tienda general'
            : 'Tienda disponible',
      ),
    ];

    return AnimatedOpacity(
      opacity: showContent ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            productName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGray,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    height: 1.0,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: stockColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: stockColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      stockLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: stockColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoPill(
                icon: Icons.qr_code_2_rounded,
                label:
                    'SKU ${product.sku.isEmpty ? product.id.toString() : product.sku}',
                accentColor: accentColor,
              ),
              _InfoPill(
                icon: Icons.category_outlined,
                label: product.categoryName.isEmpty
                    ? 'Sin categoría'
                    : product.categoryName,
                accentColor: accentColor,
              ),
              _InfoPill(
                icon: Icons.storefront_outlined,
                label: product.categoryName.isEmpty
                    ? 'Tienda general'
                    : 'Tienda disponible',
                accentColor: accentColor,
              ),
              _InfoPill(
                icon: Icons.inventory_2_outlined,
                label: product.stock > 0 ? 'En stock' : 'Sin stock',
                accentColor: accentColor,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Descripción',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGray,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  (product.description).trim().isNotEmpty
                      ? product.description
                      : (product.sku.isEmpty && product.name.isEmpty
                            ? 'Detalle del producto disponible próximamente.'
                            : 'Producto disponible en el catálogo de ${product.categoryName.isEmpty ? 'la tienda' : product.categoryName}.'),
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.7,
                    color: AppColors.mediumGray,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Características',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGray,
                  ),
                ),
                const SizedBox(height: 14),
                ...infoItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(item.icon, size: 18, color: accentColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.mediumGray,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.value,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  if (kIsWeb) {
                    navigateToExternalCatalog(
                      'https://bazarypapelerianicole.github.io/bazarproject/#/catalog',
                    );
                  } else {
                    Navigator.pushReplacementNamed(context, '/catalog');
                  }
                }
              },
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Volver'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accentColor,
                side: BorderSide(color: accentColor.withValues(alpha: 0.2)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RoundBackButton extends StatelessWidget {
  const _RoundBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_back_rounded),
        color: AppColors.darkGray,
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accentColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accentColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGray,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailItem {
  const _DetailItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;
}

Widget _fallbackDecoration(Color accentColor) {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [accentColor, accentColor.withValues(alpha: 0.65)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: const Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Colors.white70,
        size: 56,
      ),
    ),
  );
}
