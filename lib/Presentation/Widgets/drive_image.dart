// Web delega la descarga al elemento `HTMLImageElement` del navegador y las
// plataformas nativas usan el pipeline de imágenes de Flutter.
export 'drive_image_native.dart'
    if (dart.library.js_interop) 'drive_image_web.dart';
