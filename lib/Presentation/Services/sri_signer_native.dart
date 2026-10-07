import 'package:sri_xml_validator/sri_xml_validator.dart';

import 'sri_signer.dart';

class SriNativeSigner implements SriSigner {
  @override
  bool get isSupported => true;

  @override
  Future<SriSignerResult> signXml({
    required List<int> p12Bytes,
    required String p12Password,
    required String xmlSinFirmar,
    required String claveAcceso,
    required String xsdFileName,
  }) async {
    try {
      final sri = SriClient(ambiente: AmbienteSri.pruebas);
      await sri.inicializarEsquemas();
      final resultado = await sri.emitirComprobanteCompleto(
        p12Bytes: p12Bytes,
        p12Password: p12Password,
        xmlSinFirmar: xmlSinFirmar,
        claveAcceso: claveAcceso,
        xsdFileName: xsdFileName,
      );

      if (resultado.esExitoso) {
        return SriSignerResult.successful(
          resultado.xmlAutorizado ?? xmlSinFirmar,
        );
      }

      final messages = resultado.mensajes
          .map((m) => '${m.tipo} ${m.identificador}: ${m.mensaje}')
          .join('; ');
      return SriSignerResult.failed(
        messages.isEmpty ? 'No se pudo firmar el XML.' : messages,
      );
    } on SecurityException catch (error) {
      return SriSignerResult.failed(
        'Error de seguridad del certificado: $error',
      );
    } on FormatException catch (error) {
      return SriSignerResult.failed('XML no válido para el XSD SRI: $error');
    } on Exception catch (error) {
      return SriSignerResult.failed('Error al firmar el XML: $error');
    }
  }
}
