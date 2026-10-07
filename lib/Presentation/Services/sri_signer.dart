import 'package:flutter/foundation.dart';

import 'sri_signer_unsupported_factory.dart'
    if (dart.library.io) 'sri_signer_io_factory.dart'
    as platform_factory;

class SriSignerResult {
  const SriSignerResult({
    required this.supported,
    this.success = false,
    this.message = '',
    this.signedXml,
  });

  final bool supported;
  final bool success;
  final String message;
  final String? signedXml;

  bool get isUnsupported => supported == false;

  factory SriSignerResult.unsupported() {
    return const SriSignerResult(
      supported: false,
      message: 'Firma electrónica no soportada en esta plataforma',
    );
  }

  factory SriSignerResult.successful(String signedXml) {
    return SriSignerResult(
      supported: true,
      success: true,
      message: 'Factura firmada correctamente.',
      signedXml: signedXml,
    );
  }

  factory SriSignerResult.failed(String message) {
    return SriSignerResult(supported: true, success: false, message: message);
  }
}

abstract class SriSigner {
  bool get isSupported;

  Future<SriSignerResult> signXml({
    required List<int> p12Bytes,
    required String p12Password,
    required String xmlSinFirmar,
    required String claveAcceso,
    required String xsdFileName,
  });
}

class SriUnsupportedSigner implements SriSigner {
  @override
  bool get isSupported => false;

  @override
  Future<SriSignerResult> signXml({
    required List<int> p12Bytes,
    required String p12Password,
    required String xmlSinFirmar,
    required String claveAcceso,
    required String xsdFileName,
  }) async {
    return SriSignerResult.unsupported();
  }
}

class SriSignerFactory {
  static SriSigner create({TargetPlatform? platformOverride}) {
    return platform_factory.createSriSigner(
      platformOverride ?? defaultTargetPlatform,
    );
  }
}
