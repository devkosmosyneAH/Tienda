import 'package:tienda/Presentation/View/Catalog/web_history_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:tienda/Presentation/Template/catalog_template.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/View/Catalog/product_detail_page.dart';
import 'package:tienda/Presentation/Widgets/drive_image.dart';
import 'package:tienda/Presentation/Widgets/product_gallery_viewer.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Bottom sheet de detalle de una categoría del catálogo.
/// Muestra imagen grande, descripción completa, tags y productos disponibles.
class CatalogDetailWidget extends StatelessWidget {
  final String name;
  final String storeName;
  final CategoryInfo info;

  const CatalogDetailWidget({
    super.key,
    required this.name,
    required this.storeName,
    required this.info,
  });

  bool get _isBazar => storeName.toLowerCase() == 'bazar';

  Color get _accent =>
      _isBazar ? AppColors.blackOverlay : const Color(0xFF2E7D32);

  String get _storeLabel => _isBazar ? 'Bazar Nicole' : storeName;

  IconData get _storeIcon =>
      _isBazar ? Icons.shopping_bag_outlined : Icons.menu_book_outlined;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isWide = MediaQuery.of(context).size.width > 700;
    final galleryImages = info.heroImages.isNotEmpty
        ? info.heroImages
        : info.imageFile == null
        ? const <CatalogImageFile>[]
        : [info.imageFile!];

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.greyOverlay,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Contenido scrollable
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // ── Imagen hero ────────────────────────────────
                    _HeroImage(
                      imageFiles: galleryImages,
                      imageUrl: info.imageUrl,
                      accentColor: _accent,
                      height: isWide ? screenHeight * 0.3 : screenHeight * 0.26,
                    ),

                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWide ? 40 : 20,
                        vertical: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Tienda badge ───────────────────────
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _accent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _storeIcon,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _storeLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              // Disponibilidad
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF43A047),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Disponible',
                                    style: TextStyle(
                                      color: AppColors.mediumGray,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // ── Nombre ─────────────────────────────
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: isWide ? 26 : 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkGray,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── Descripción completa ───────────────
                          Text(
                            info.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.mediumGray,
                              height: 1.65,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // ── Tags ───────────────────────────────
                          if (info.tags.isNotEmpty) ...[
                            Text(
                              'Etiquetas',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkGray,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: info.tags
                                  .map(
                                    (t) => _DetailTag(label: t, color: _accent),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // ── Productos reales (si vienen de Drive) ───
                          if (info.products.isNotEmpty) ...[
                            Text(
                              'Productos disponibles (${info.products.length})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkGray,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _ProductList(
                              products: info.products,
                              accentColor: _accent,
                            ),
                            const SizedBox(height: 20),
                          ],

                          // ── Código QR de la categoría ───────────
                          _CategoryQr(categoryName: name, accentColor: _accent),

                          const SizedBox(height: 24),

                          // ── Llamado a la acción ─────────────────
                          _ContactCTA(accentColor: _accent),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Imagen hero en la parte superior del detalle.
class _HeroImage extends StatelessWidget {
  final List<CatalogImageFile> imageFiles;
  final String imageUrl;
  final Color accentColor;
  final double height;

  const _HeroImage({
    required this.imageFiles,
    required this.imageUrl,
    required this.accentColor,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final file = imageFiles.isEmpty ? null : imageFiles.first;
    if (imageUrl.trim().isNotEmpty) {
      return SizedBox(
        height: height,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withValues(alpha: 0.5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.photo_library_outlined,
              color: Colors.white38,
              size: 64,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (file != null)
            Semantics(
              button: true,
              label: 'Ampliar galería de imágenes',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => ProductGalleryViewer.show(
                    context,
                    images: imageFiles
                        .map((image) => image.thumbnailLink)
                        .toList(),
                  ),
                  child: Hero(
                    tag: ProductGalleryViewer.heroTagFor(file.thumbnailLink),
                    child: DriveImage(
                      url: file.thumbnailLink,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentColor,
                              accentColor.withValues(alpha: 0.5),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          Icons.photo_library_outlined,
                          color: Colors.white38,
                          size: 64,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withValues(alpha: 0.5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                color: Colors.white38,
                size: 64,
              ),
            ),
          // Gradiente inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 80,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip de tag con borde y color de acento.
class _DetailTag extends StatelessWidget {
  final String label;
  final Color color;

  const _DetailTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Sección con código QR que apunta al catálogo web filtrado por categoría.
class _CategoryQr extends StatelessWidget {
  final String categoryName;
  final Color accentColor;

  const _CategoryQr({required this.categoryName, required this.accentColor});

  String get _qrUrl =>
      'https://bazarypapelerianicole.github.io/bazarproject/#/catalog?categoria=${Uri.encodeComponent(categoryName)}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_2_rounded, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Código QR de esta categoría',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: QrImageView(
              data: _qrUrl,
              version: QrVersions.auto,
              size: 180,
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: accentColor,
              ),
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _qrUrl,
            style: TextStyle(
              fontSize: 10,
              color: accentColor.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Sección de llamado a la acción al final del detalle.
class _ContactCTA extends StatelessWidget {
  final Color accentColor;

  const _ContactCTA({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Te interesa este artículo?',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'Visítanos en tienda o contáctanos para más información.',
                  style: TextStyle(fontSize: 11, color: AppColors.mediumGray),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: accentColor, size: 22),
        ],
      ),
    );
  }
}

// ── Lista de productos reales de Drive ────────────────────────────────────────

/// Lista compacta de productos reales de la categoría, con nombre, SKU y precio.
class _ProductList extends StatelessWidget {
  final List<CatalogProductEntry> products;
  final Color accentColor;

  const _ProductList({required this.products, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: products
          .map((p) => _ProductRow(product: p, color: accentColor))
          .toList(),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final CatalogProductEntry product;
  final Color color;

  const _ProductRow({required this.product, required this.color});

  String get _qrUrl =>
      'https://bazarypapelerianicole.github.io/bazarproject/#/catalog/${Uri.encodeComponent(product.sku.isNotEmpty ? product.sku : product.id.toString())}';

  @override
  Widget build(BuildContext context) {
    final imageFile = product.imageFiles.isEmpty
        ? null
        : product.imageFiles.first;
    if (imageFile != null) {
      // ignore: avoid_print
      print('[PARENT] URL enviada a DriveImage: ${imageFile.thumbnailLink}');
    }
    return InkWell(
      onTap: () {
        if (kIsWeb) {
          final sku = product.sku.isNotEmpty
              ? product.sku
              : product.id.toString();
          final url = '/catalog/${Uri.encodeComponent(sku)}';
          try {
            GoRouter.of(context).go(url);
          } catch (_) {
            replaceWebUrl(url);
          }
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(product: product),
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // La URL es el thumbnailLink original del archivo de Drive.
            imageFile != null
                ? Semantics(
                    button: true,
                    label: 'Ampliar imágenes de ${product.name}',
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          ProductGalleryViewer.show(
                            context,
                            images: product.imageFiles
                                .map((image) => image.thumbnailLink)
                                .toList(),
                          );
                        },
                        child: Hero(
                          tag: ProductGalleryViewer.heroTagFor(
                            imageFile.thumbnailLink,
                          ),
                          child: DriveImage(
                            url: imageFile.thumbnailLink,
                            width: 34,
                            height: 34,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(8),
                            errorWidget: _productIcon(),
                          ),
                        ),
                      ),
                    ),
                  )
                : SizedBox(width: 34, height: 34, child: _productIcon()),

            const SizedBox(width: 10),
            // Nombre y SKU
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (product.sku.isNotEmpty)
                    Text(
                      'SKU: ${product.sku}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.mediumGray,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Precio y stock
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (product.stock > 0)
                  Text(
                    '${product.stock} en stock',
                    style: TextStyle(fontSize: 10, color: AppColors.mediumGray),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            // Código QR del producto — toca para ampliar
            GestureDetector(
              onTap: () => _showQrDialog(context),
              child: QrImageView(
                data: _qrUrl,
                version: QrVersions.auto,
                size: 52,
                eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: color),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productIcon() => Container(
    color: color.withValues(alpha: 0.1),
    child: Icon(Icons.inventory_2_outlined, color: color, size: 18),
  );

  void _showQrDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => SelectionArea(
        child: Dialog(
          backgroundColor: AppColors.lightGray,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.qr_code_2_rounded,
                          color: color,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Código QR del producto',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Escanea para ver el producto en el catálogo',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                color: AppColors.mediumGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        tooltip: 'Cerrar',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.16)),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.10),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: _qrUrl,
                      version: QrVersions.auto,
                      size: 228,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: color,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (product.sku.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'SKU: ${product.sku}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.mediumGray,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _qrUrl,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.35,
                        color: AppColors.mediumGray,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Listo'),
                      style: FilledButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
