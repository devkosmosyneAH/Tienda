// ignore_for_file: file_names

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resultado de una imagen optimizada lista para subir.
class OptimizedImage {
  final File file;
  final String mimeType;
  final String extension;
  final int originalSize;
  final int optimizedSize;
  final double savingPercent;

  OptimizedImage({
    required this.file,
    required this.mimeType,
    required this.extension,
    required this.originalSize,
    required this.optimizedSize,
    required this.savingPercent,
  });
}

class ImageOptimizerService {
  static const int _maxBytes = 1 * 1024 * 1024; // 1 MB
  static const int _qualityStart = 90;
  static const int _qualityMin = 70;

  /// Optimiza una imagen desde una ruta local o un File.
  /// Retorna un [OptimizedImage] con un archivo temporal en WebP.
  static Future<OptimizedImage> optimize(
    dynamic source, {
    void Function(String)? onProgress,
  }) async {
    // Optimización orientada a plataformas locales (no Web).

    final File sourceFile = _resolveSourceFile(source);
    if (!await sourceFile.exists()) {
      throw Exception('Archivo no encontrado: ${sourceFile.path}');
    }

    onProgress?.call('Optimizando imagen...');
    final originalBytes = await sourceFile.readAsBytes();
    final originalSize = originalBytes.length;
    final originalName = p.basename(sourceFile.path);
    final stopwatch = Stopwatch()..start();

    try {
      final compressedBytes = await _compressToWebp(sourceFile);
      if (compressedBytes == null || compressedBytes.isEmpty) {
        throw Exception('La compresión devolvió un archivo vacío.');
      }

      onProgress?.call('Optimización completada');
      stopwatch.stop();

      final tempDir = await getTemporaryDirectory();
      final tempFileName =
          '${DateTime.now().microsecondsSinceEpoch}_${p.setExtension(p.basenameWithoutExtension(originalName), '.webp')}';
      final tempFile = File(p.join(tempDir.path, tempFileName));
      await tempFile.writeAsBytes(compressedBytes, flush: true);

      final int optimizedSize = compressedBytes.length;
      final double savingPercent = originalSize == 0
          ? 0.0
          : (1 - (optimizedSize / originalSize)) * 100;

      _logSummary(
        originalName: originalName,
        originalSize: originalSize,
        optimizedSize: optimizedSize,
        durationMs: stopwatch.elapsedMilliseconds,
      );

      return OptimizedImage(
        file: tempFile,
        mimeType: 'image/webp',
        extension: 'webp',
        originalSize: originalSize,
        optimizedSize: optimizedSize,
        savingPercent: savingPercent,
      );
    } catch (e, st) {
      debugPrint('Error durante la optimización de $originalName: $e');
      debugPrint(st.toString());
      onProgress?.call('Error al optimizar la imagen');
      rethrow;
    }
  }

  static File _resolveSourceFile(dynamic source) {
    if (source is File) return source;
    if (source is String) return File(source);
    throw ArgumentError.value(
      source,
      'source',
      'El origen debe ser un File o una ruta de archivo local.',
    );
  }

  static Future<Uint8List?> _compressToWebp(File sourceFile) async {
    int quality = _qualityStart;
    Uint8List? compressedBytes;

    while (quality >= _qualityMin) {
      compressedBytes = await FlutterImageCompress.compressWithFile(
        sourceFile.path,
        format: CompressFormat.webp,
        quality: quality,
        keepExif: true,
      );

      if (compressedBytes != null &&
          compressedBytes.isNotEmpty &&
          compressedBytes.length <= _maxBytes) {
        return compressedBytes;
      }

      quality -= 5;
    }

    return compressedBytes;
  }

  static void _logSummary({
    required String originalName,
    required int originalSize,
    required int optimizedSize,
    required int durationMs,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('══════════════════════════════');
    buffer.writeln('Imagen original');
    buffer.writeln(originalName);
    buffer.writeln('${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');
    buffer.writeln('\n↓\n');
    buffer.writeln('WEBP');
    buffer.writeln('${(optimizedSize / 1024).round()} KB');
    final saving = originalSize == 0
        ? 0
        : (1 - (optimizedSize / originalSize)) * 100;
    buffer.writeln('\nAhorro');
    buffer.writeln('${saving.toStringAsFixed(0)} %');
    buffer.writeln('\nTiempo');
    buffer.writeln('$durationMs ms');
    buffer.writeln('══════════════════════════════');
    debugPrint(buffer.toString());
  }
}
