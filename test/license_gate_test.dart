import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tienda/Presentation/Controller/license_provider.dart';
import 'package:tienda/Presentation/Services/license_service.dart';
import 'package:tienda/Presentation/Widgets/license_gate.dart';

void main() {
  testWidgets(
    'el campo de activación funciona cuando la licencia está bloqueada',
    (WidgetTester tester) async {
      final licenseProvider = LicenseProvider(
        service: LocalLicenseService(
          persistence: _ExpiredLicensePersistence(),
          fingerprint: _TestFingerprint(),
          clock: _TestClock(),
          idGenerator: _TestIdGenerator(),
          verifier: Ed25519LicenseCodeVerifier(publicKeyBase64: ''),
        ),
      );
      try {
        await licenseProvider.initialize();

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: licenseProvider,
            child: MaterialApp(
              home: LicenseGate(
                child: const Scaffold(body: Text('Contenido')),
                onStatusTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final activationCodeField = find.byType(TextField);
        expect(activationCodeField, findsOneWidget);

        await tester.tap(activationCodeField);
        await tester.pump();
        await tester.enterText(activationCodeField, 'CODIGO-DE-PRUEBA');
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('CODIGO-DE-PRUEBA'), findsOneWidget);
      } finally {
        licenseProvider.dispose();
      }
    },
  );
}

class _ExpiredLicensePersistence implements LicensePersistence {
  @override
  Future<StoredLicenseState> read(String fingerprint) async =>
      StoredLicenseState(
        record: LicenseRecord(
          installationId: 'test-installation',
          fingerprint: fingerprint,
          demoStartedAt: DateTime.utc(2020),
          lastSeenAt: DateTime.utc(2020),
        ),
        foundData: true,
      );

  @override
  Future<void> write(LicenseRecord record) async {}
}

class _TestFingerprint implements LicenseFingerprint {
  @override
  Future<String> current() async => 'test-fingerprint';
}

class _TestClock implements LicenseClock {
  @override
  DateTime nowUtc() => DateTime.utc(2026);
}

class _TestIdGenerator implements LicenseIdGenerator {
  @override
  String generate() => 'test-installation';
}
