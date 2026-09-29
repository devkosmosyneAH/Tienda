import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) _usage();
  switch (arguments.first) {
    case 'keygen':
      await _generateKeyPair(arguments);
    case 'issue':
      await _issueCode(arguments);
    default:
      _usage();
  }
}

Future<void> _generateKeyPair(List<String> arguments) async {
  if (arguments.length != 3) _usage();
  final privatePath = arguments[1];
  final publicPath = arguments[2];
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPair();
  final privateData = await keyPair.extract();
  final publicKey = await keyPair.extractPublicKey();
  final privateFile = File(privatePath);
  final publicFile = File(publicPath);
  await privateFile.parent.create(recursive: true);
  await publicFile.parent.create(recursive: true);
  await privateFile.writeAsString(
    jsonEncode({
      'algorithm': 'Ed25519',
      'seed': base64Url.encode(privateData.bytes),
    }),
    flush: true,
  );
  await publicFile.writeAsString(
    base64Url.encode(publicKey.bytes),
    flush: true,
  );
  if (!Platform.isWindows) {
    await Process.run('chmod', ['600', privateFile.path]);
  }
  stdout.writeln('Clave privada creada en: $privatePath');
  stdout.writeln('Clave pública creada en: $publicPath');
}

Future<void> _issueCode(List<String> arguments) async {
  if (arguments.length < 5 || arguments.length > 6) _usage();
  final privateFile = File(arguments[1]);
  if (!await privateFile.exists()) {
    stderr.writeln('No existe el archivo de clave privada indicado.');
    exitCode = 2;
    return;
  }
  final privateKeyJson =
      jsonDecode(await privateFile.readAsString()) as Map<String, dynamic>;
  if (privateKeyJson['algorithm'] != 'Ed25519') {
    stderr.writeln('El archivo no contiene una clave Ed25519 compatible.');
    exitCode = 2;
    return;
  }
  final seed = base64Url.decode(
    base64Url.normalize(privateKeyJson['seed'] as String),
  );
  final validity = arguments[4].toLowerCase();
  final expiresAt = validity == 'perpetual'
      ? null
      : DateTime.now().toUtc().add(Duration(days: int.parse(validity)));
  final isRevoked = arguments.length == 6 && arguments[5] == 'revoked';
  final issuedAt = DateTime.now().toUtc();
  final payload = jsonEncode({
    'version': 1,
    'installationId': arguments[2],
    'fingerprint': arguments[3],
    'issuedAt': issuedAt.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'licenseId': const Uuid().v4(),
    'revoked': isRevoked,
  });
  final payloadPart = base64Url.encode(utf8.encode(payload));
  final keyPair = await Ed25519().newKeyPairFromSeed(seed);
  final signature = await Ed25519().sign(
    utf8.encode(payloadPart),
    keyPair: keyPair,
  );
  stdout.writeln('DK1.$payloadPart.${base64Url.encode(signature.bytes)}');
}

Never _usage() {
  stderr.writeln('''
Uso:
  dart run tool/license_issuer.dart keygen <clave-privada.json> <clave-publica.txt>
  dart run tool/license_issuer.dart issue <clave-privada.json> <installation-id> <fingerprint> <días|perpetual> [revoked]

La clave privada se genera y usa offline. No la incluyas en el código ni en el instalador.
''');
  exit(2);
}
