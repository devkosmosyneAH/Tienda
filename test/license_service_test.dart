import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tienda/Presentation/Controller/license_provider.dart';
import 'package:tienda/Presentation/Services/license_service.dart';
import 'package:tienda/Presentation/Services/license_storage.dart';
import 'package:tienda/Presentation/Widgets/license_gate.dart';

void main() {
  final start = DateTime.utc(2026, 1, 1, 12);
  const fingerprintValue = 'machine-fingerprint';
  const installationIdValue = 'installation-one';
  final algorithm = Ed25519();
  late SimpleKeyPair keyPair;
  late String publicKey;

  setUpAll(() async {
    keyPair = await algorithm.newKeyPairFromSeed(
      List<int>.generate(32, (i) => i + 1),
    );
    final publicKeyData = await keyPair.extractPublicKey();
    publicKey = base64Url.encode(publicKeyData.bytes);
  });

  LocalLicenseService createService({
    required FakePersistence persistence,
    required FakeClock clock,
    String fingerprint = fingerprintValue,
  }) => LocalLicenseService(
    persistence: persistence,
    fingerprint: FakeFingerprint(fingerprint),
    clock: clock,
    idGenerator: FakeIdGenerator(
      fingerprint == fingerprintValue
          ? installationIdValue
          : '$fingerprint-installation',
    ),
    verifier: Ed25519LicenseCodeVerifier(publicKeyBase64: publicKey),
  );

  Future<String> issueCode({
    required String installationId,
    required String fingerprint,
    DateTime? expiresAt,
    bool revoked = false,
  }) async {
    final payload = jsonEncode({
      'version': 1,
      'installationId': installationId,
      'fingerprint': fingerprint,
      'issuedAt': start.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'licenseId': 'license-test',
      'revoked': revoked,
    });
    final payloadPart = base64Url.encode(utf8.encode(payload));
    final signature = await algorithm.sign(
      utf8.encode(payloadPart),
      keyPair: keyPair,
    );
    return 'DK1.$payloadPart.${base64Url.encode(signature.bytes)}';
  }

  group('LocalLicenseService', () {
    test('inicia Demo persistente por 168 horas exactas', () async {
      final clock = FakeClock(start);
      final persistence = FakePersistence();
      final first = await createService(
        persistence: persistence,
        clock: clock,
      ).initialize();

      expect(first.status, LicenseStatus.DEMO_ACTIVA);
      expect(first.demoStartedAt, start);
      expect(first.remaining, const Duration(hours: 168));
      expect(persistence.record?.installationId, installationIdValue);

      clock.value = start.add(const Duration(days: 1));
      final afterRestart = await createService(
        persistence: persistence,
        clock: clock,
      ).initialize();

      expect(afterRestart.demoStartedAt, start);
      expect(afterRestart.remaining, const Duration(days: 6));
    });

    test('marca Demo por vencer durante las últimas 24 horas', () async {
      final clock = FakeClock(start);
      final service = createService(
        persistence: FakePersistence(),
        clock: clock,
      );
      await service.initialize();
      clock.value = start.add(const Duration(days: 6));
      final snapshot = await service.refresh();

      expect(snapshot.status, LicenseStatus.DEMO_POR_VENCER);
      expect(snapshot.remaining, const Duration(days: 1));
    });

    test(
      'vence justo al cumplirse las 168 horas y bloquea el acceso',
      () async {
        final clock = FakeClock(start);
        final service = createService(
          persistence: FakePersistence(),
          clock: clock,
        );
        await service.initialize();
        clock.value = start.add(const Duration(hours: 168));
        final snapshot = await service.refresh();

        expect(snapshot.status, LicenseStatus.DEMO_VENCIDA);
        expect(snapshot.isBlocked, isTrue);
        expect(snapshot.remaining, Duration.zero);
      },
    );

    test(
      'rechaza códigos incorrectos sin reemplazar el estado actual',
      () async {
        final persistence = FakePersistence();
        final service = createService(
          persistence: persistence,
          clock: FakeClock(start),
        );
        await service.initialize();

        final result = await service.activate('DK1.codigo.firma-invalida');

        expect(result.activated, isFalse);
        expect(persistence.record?.activationCode, isNull);
      },
    );

    test(
      'activa y conserva una licencia válida tras reinicializar el servicio',
      () async {
        final persistence = FakePersistence();
        final clock = FakeClock(start);
        final service = createService(persistence: persistence, clock: clock);
        await service.initialize();
        final code = await issueCode(
          installationId: installationIdValue,
          fingerprint: fingerprintValue,
        );

        final result = await service.activate(code);
        final restarted = await createService(
          persistence: persistence,
          clock: clock,
        ).initialize();

        expect(result.activated, isTrue);
        expect(restarted.status, LicenseStatus.LICENCIA_ACTIVA);
        expect(restarted.isBlocked, isFalse);
      },
    );

    test(
      'rechaza una licencia expirada o revocada aunque su firma sea válida',
      () async {
        final expiredPersistence = FakePersistence();
        final expiredService = createService(
          persistence: expiredPersistence,
          clock: FakeClock(start),
        );
        await expiredService.initialize();
        final expiredCode = await issueCode(
          installationId: installationIdValue,
          fingerprint: fingerprintValue,
          expiresAt: start,
        );
        final expiredResult = await expiredService.activate(expiredCode);

        final revokedPersistence = FakePersistence();
        final revokedService = createService(
          persistence: revokedPersistence,
          clock: FakeClock(start),
        );
        await revokedService.initialize();
        final revokedCode = await issueCode(
          installationId: installationIdValue,
          fingerprint: fingerprintValue,
          revoked: true,
        );
        final revokedResult = await revokedService.activate(revokedCode);

        expect(expiredResult.activated, isFalse);
        expect(
          expiredService.snapshot?.status,
          LicenseStatus.LICENCIA_EXPIRADA,
        );
        expect(revokedResult.activated, isFalse);
        expect(
          revokedService.snapshot?.status,
          LicenseStatus.LICENCIA_REVOCADA,
        );
      },
    );

    test('detecta retroceso brusco de fecha del sistema', () async {
      final persistence = FakePersistence();
      final clock = FakeClock(start);
      await createService(persistence: persistence, clock: clock).initialize();
      clock.value = start.subtract(const Duration(hours: 1));

      final restarted = await createService(
        persistence: persistence,
        clock: clock,
      ).initialize();

      expect(restarted.status, LicenseStatus.LICENCIA_INVALIDA);
      expect(restarted.isBlocked, isTrue);
    });

    test('mantiene estados separados para instalaciones distintas', () async {
      final sharedStorage = FakePersistence();
      final clock = FakeClock(start);
      final first = await createService(
        persistence: sharedStorage,
        clock: clock,
      ).initialize();
      final second = await createService(
        persistence: FakePersistence(),
        clock: clock,
        fingerprint: 'another-machine',
      ).initialize();

      expect(first.installationId, isNot(second.installationId));
      expect(first.fingerprint, isNot(second.fingerprint));
      expect(first.demoStartedAt, second.demoStartedAt);
    });

    test('rechaza el código firmado para otra instalación', () async {
      final persistence = FakePersistence();
      final service = createService(
        persistence: persistence,
        clock: FakeClock(start),
      );
      await service.initialize();
      final code = await issueCode(
        installationId: 'other-installation',
        fingerprint: fingerprintValue,
      );

      final result = await service.activate(code);

      expect(result.activated, isFalse);
      expect(persistence.record?.activationCode, isNull);
    });

    test(
      'almacenamiento corrupto queda bloqueado y admite código de recuperación',
      () async {
        final persistence = FakePersistence()
          ..foundData = true
          ..corrupt = true;
        final service = createService(
          persistence: persistence,
          clock: FakeClock(start),
        );

        final invalid = await service.initialize();
        final recoveryCode = await issueCode(
          installationId: invalid.installationId,
          fingerprint: fingerprintValue,
        );
        final activation = await service.activate(recoveryCode);

        expect(invalid.status, LicenseStatus.LICENCIA_INVALIDA);
        expect(invalid.isBlocked, isTrue);
        expect(invalid.installationId, isNotEmpty);
        expect(activation.activated, isTrue);
        expect(service.snapshot?.status, LicenseStatus.LICENCIA_ACTIVA);
      },
    );

    testWidgets('la Demo vencida bloquea el POS y muestra activación', (
      tester,
    ) async {
      final persistence = FakePersistence();
      final clock = FakeClock(start);
      final service = createService(persistence: persistence, clock: clock);
      await service.initialize();
      clock.value = start.add(const Duration(hours: 168));
      await service.refresh();
      final provider = LicenseProvider(service: service);
      await provider.initialize();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: LicenseGate(
              child: const Text('POS principal'),
              onStatusTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('POS principal'), findsNothing);
      expect(find.text('Período de prueba finalizado'), findsOneWidget);
      expect(find.text('Activar licencia'), findsOneWidget);
      expect(find.text('+593 95 983 1092'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });
  });

  group('LocalLicensePersistence', () {
    test('recupera desde SQLite si se elimina el archivo paralelo', () async {
      final sqlite = FakeBlobStore();
      final file = FakeBlobStore();
      final persistence = LocalLicensePersistence(sqlite: sqlite, file: file);
      final record = LicenseRecord(
        installationId: installationIdValue,
        fingerprint: fingerprintValue,
        demoStartedAt: start,
        lastSeenAt: start,
      );
      await persistence.write(record);
      file.value = null;

      final restored = await persistence.read(fingerprintValue);

      expect(restored.record?.demoStartedAt, start);
      expect(restored.corrupt, isFalse);
    });

    test('no trata copias existentes ilegibles como una Demo nueva', () async {
      final persistence = LocalLicensePersistence(
        sqlite: FakeBlobStore()..value = 'roto-a',
        file: FakeBlobStore()..value = 'roto-b',
      );

      final stored = await persistence.read(fingerprintValue);

      expect(stored.foundData, isTrue);
      expect(stored.corrupt, isTrue);
      expect(stored.record, isNull);
    });
  });
}

class FakePersistence implements LicensePersistence {
  LicenseRecord? record;
  bool foundData = false;
  bool corrupt = false;

  @override
  Future<StoredLicenseState> read(String fingerprint) async =>
      StoredLicenseState(
        record: record,
        foundData: record != null || foundData,
        corrupt: corrupt,
      );

  @override
  Future<void> write(LicenseRecord value) async {
    record = value;
    foundData = true;
    corrupt = false;
  }
}

class FakeFingerprint implements LicenseFingerprint {
  const FakeFingerprint(this.value);

  final String value;

  @override
  Future<String> current() async => value;
}

class FakeClock implements LicenseClock {
  FakeClock(this.value);

  DateTime value;

  @override
  DateTime nowUtc() => value;
}

class FakeIdGenerator implements LicenseIdGenerator {
  const FakeIdGenerator(this.value);

  final String value;

  @override
  String generate() => value;
}

class FakeBlobStore implements LicenseBlobStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String newValue) async {
    value = newValue;
  }
}
