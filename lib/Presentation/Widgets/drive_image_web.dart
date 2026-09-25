import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:web/web.dart' as web;

/// Imagen remota para Flutter Web cargada directamente por el navegador.
///
/// Se crea un único [web.HTMLImageElement] por widget. No se precarga ni se
/// prueba la URL con un segundo elemento, porque algunos proveedores (como
/// Google Drive) entregan URLs y redirecciones que no son reutilizables entre
/// dos solicitudes independientes.
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

  /// Se mantienen por compatibilidad con los consumidores existentes.
  /// El navegador gestiona la carga directamente, por lo que no se muestra un
  /// placeholder durante una precarga inexistente.
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: errorWidget ?? placeholder ?? const SizedBox.shrink(),
      );
    }

    final image = HtmlElementView.fromTagName(
      key: ValueKey((url, fit, borderRadius)),
      tagName: 'img',
      hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      onElementCreated: (element) {
        final img = element as web.HTMLImageElement;
        img
          ..src = url
          ..alt = '';
        img.style
          ..width = '100%'
          ..height = '100%'
          ..display = 'block'
          ..opacity = '0'
          ..objectFit = _objectFit(fit)
          ..objectPosition = 'center'
          ..pointerEvents = 'none';
        img.setAttribute('decoding', 'async');
        img.onLoad.listen((_) => img.style.opacity = '1');
        img.onError.listen((_) => img.style.opacity = '0');
        if (borderRadius != null) {
          img.style.setProperty(
            'border-radius',
            _borderRadiusCss(borderRadius!),
          );
        }
      },
    );

    final fallback = errorWidget ?? placeholder ?? const SizedBox.shrink();
    final renderedImage = borderRadius == null
        ? image
        : ClipRRect(borderRadius: borderRadius!, child: image);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(fit: StackFit.expand, children: [fallback, renderedImage]),
    );
  }
}

String _objectFit(BoxFit fit) => switch (fit) {
  BoxFit.fill => 'fill',
  BoxFit.contain => 'contain',
  BoxFit.cover => 'cover',
  BoxFit.none => 'none',
  BoxFit.scaleDown => 'scale-down',
  BoxFit.fitWidth || BoxFit.fitHeight => 'cover',
};

String _borderRadiusCss(BorderRadius radius) {
  String values(bool horizontal) => [
    radius.topLeft,
    radius.topRight,
    radius.bottomRight,
    radius.bottomLeft,
  ].map((corner) => '${horizontal ? corner.x : corner.y}px').join(' ');

  return '${values(true)} / ${values(false)}';
}
