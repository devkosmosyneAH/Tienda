import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:tienda/Presentation/Widgets/gallery_arrow.dart';
import 'package:tienda/Presentation/Widgets/gallery_close_button.dart';
import 'package:tienda/Presentation/Widgets/gallery_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// Visor a pantalla completa para una colección de URLs de imágenes.
///
/// El widget no conoce modelos del catálogo. Para conservar la animación Hero,
/// envuelva la imagen de origen en un [Hero] usando [heroTagFor].
class ProductGalleryViewer extends StatefulWidget {
  const ProductGalleryViewer({
    super.key,
    required this.images,
    required this.initialIndex,
  }) : assert(images.length > 0, 'ProductGalleryViewer necesita una imagen');

  final List<String> images;
  final int initialIndex;

  /// Tag estable que deben usar las imágenes de origen del Hero.
  static String heroTagFor(String imageUrl) =>
      'product-gallery-image:$imageUrl';

  /// Abre el visor sin cambiar la ruta de la página actual.
  static Future<T?> show<T>(
    BuildContext context, {
    required List<String> images,
    int initialIndex = 0,
  }) {
    if (images.isEmpty) return Future<T?>.value(null);
    final safeIndex = initialIndex.clamp(0, images.length - 1);

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar visor de imágenes',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, _, __) => ProductGalleryViewer(
        images: images,
        initialIndex: safeIndex,
      ),
      transitionBuilder: (_, animation, __, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.975, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<ProductGalleryViewer> createState() => _ProductGalleryViewerState();
}

class _ProductGalleryViewerState extends State<ProductGalleryViewer> {
  late final ValueNotifier<int> _currentIndex;
  late final FocusNode _focusNode;
  int _lastTrackpadDirection = 0;
  Timer? _trackpadDebounce;

  @override
  void initState() {
    super.initState();
    _currentIndex = ValueNotifier<int>(
      widget.initialIndex.clamp(0, widget.images.length - 1),
    );
    _focusNode = FocusNode(debugLabel: 'product-gallery-viewer');
    _currentIndex.addListener(_precacheAdjacentImages);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        _precacheAdjacentImages();
      }
    });
  }

  @override
  void dispose() {
    _currentIndex
      ..removeListener(_precacheAdjacentImages)
      ..dispose();
    _trackpadDebounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _precacheAdjacentImages() {
    if (!mounted || widget.images.length < 2) return;
    final current = _currentIndex.value;
    final previous =
        (current - 1 + widget.images.length) % widget.images.length;
    final next = (current + 1) % widget.images.length;
    for (final index in {previous, next}) {
      final imageUrl = widget.images[index];
      final ImageProvider provider = imageUrl.startsWith('http://') ||
              imageUrl.startsWith('https://')
          ? NetworkImage(imageUrl)
          : FileImage(File(imageUrl));
      unawaited(precacheImage(provider, context));
    }
  }

  void _select(int index) {
    final normalized = (index % widget.images.length + widget.images.length) %
        widget.images.length;
    if (_currentIndex.value != normalized) _currentIndex.value = normalized;
  }

  void _previous() => _select(_currentIndex.value - 1);
  void _next() => _select(_currentIndex.value + 1);
  void _close() => Navigator.of(context).maybePop();

  KeyEventResult _onKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _previous();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _next();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || widget.images.length < 2) return;
    // Los gestos horizontales del trackpad alternan la imagen. El scroll
    // vertical queda disponible para el zoom de InteractiveViewer.
    if (event.scrollDelta.dx.abs() < 18 ||
        event.scrollDelta.dx.abs() <= event.scrollDelta.dy.abs()) {
      return;
    }
    final direction = event.scrollDelta.dx.sign.toInt();
    if (direction != _lastTrackpadDirection) {
      _lastTrackpadDirection = direction;
      direction > 0 ? _next() : _previous();
      _trackpadDebounce?.cancel();
      _trackpadDebounce = Timer(const Duration(milliseconds: 260), () {
        _lastTrackpadDirection = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: Listener(
          onPointerSignal: _onPointerSignal,
          child: Material(
            color: Colors.transparent,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // La combinación da contraste sin perder totalmente el contexto
                // de la página desde la que se abrió la galería.
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                  child: ColoredBox(color: Colors.black.withValues(alpha: 0.9)),
                ),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final showThumbnails = constraints.maxWidth >= 520;
                      final galleryWidth = constraints.maxWidth *
                          (constraints.maxWidth >= 900 ? 0.85 : 0.94);
                      return Stack(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                                bottom: showThumbnails ? 106 : 18),
                            child: Center(
                              child: SizedBox(
                                width: galleryWidth,
                                child: ValueListenableBuilder<int>(
                                  valueListenable: _currentIndex,
                                  builder: (_, index, __) => _GalleryImage(
                                    key: ValueKey(widget.images[index]),
                                    imageUrl: widget.images[index],
                                    onSwipeLeft: _next,
                                    onSwipeRight: _previous,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            left: 0,
                            right: 0,
                            child: ValueListenableBuilder<int>(
                              valueListenable: _currentIndex,
                              builder: (_, index, __) => Semantics(
                                liveRegion: true,
                                label:
                                    'Imagen ${index + 1} de ${widget.images.length}',
                                child: Text(
                                  '${index + 1} / ${widget.images.length}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    shadows: [
                                      Shadow(color: Colors.black, blurRadius: 8)
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 8,
                            child: GalleryCloseButton(onPressed: _close),
                          ),
                          if (widget.images.length > 1) ...[
                            Positioned(
                              left: 16,
                              top: 0,
                              bottom: showThumbnails ? 90 : 0,
                              child: Center(
                                child: GalleryArrow(
                                    onPressed: _previous, isPrevious: true),
                              ),
                            ),
                            Positioned(
                              right: 16,
                              top: 0,
                              bottom: showThumbnails ? 90 : 0,
                              child: Center(
                                child: GalleryArrow(
                                    onPressed: _next, isPrevious: false),
                              ),
                            ),
                          ],
                          if (showThumbnails && widget.images.length > 1)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: 92,
                              child: ValueListenableBuilder<int>(
                                valueListenable: _currentIndex,
                                builder: (_, selected, __) => ListView.builder(
                                  key: const PageStorageKey(
                                      'product-gallery-thumbnails'),
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemCount: widget.images.length,
                                  itemBuilder: (_, index) => GalleryThumbnail(
                                    imageUrl: widget.images[index],
                                    index: index,
                                    isSelected: selected == index,
                                    onTap: _select,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryImage extends StatefulWidget {
  const _GalleryImage({
    super.key,
    required this.imageUrl,
    required this.onSwipeLeft,
    required this.onSwipeRight,
  });

  final String imageUrl;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;

  @override
  State<_GalleryImage> createState() => _GalleryImageState();
}

class _GalleryImageState extends State<_GalleryImage> {
  late final TransformationController _transformController;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final isZoomed = _transformController.value.getMaxScaleOnAxis() > 1.01;
    _transformController.value =
        isZoomed ? Matrix4.identity() : Matrix4.identity()
          ..scale(2.5);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_transformController.value.getMaxScaleOnAxis() > 1.01) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 250) return;
    velocity < 0 ? widget.onSwipeLeft() : widget.onSwipeRight();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.center,
        children: [...previousChildren, if (currentChild != null) currentChild],
      ),
      child: GestureDetector(
        key: ValueKey(widget.imageUrl),
        behavior: HitTestBehavior.opaque,
        onDoubleTap: _toggleZoom,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: Hero(
          tag: ProductGalleryViewer.heroTagFor(widget.imageUrl),
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: 1,
            maxScale: 5,
            trackpadScrollCausesScale: true,
            boundaryMargin: const EdgeInsets.all(80),
            child: Image.file(
              File(widget.imageUrl),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: Colors.white54, size: 56),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
