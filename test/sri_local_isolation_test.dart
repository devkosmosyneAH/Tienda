import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tienda/Presentation/Model/sri_store_config_model.dart';
import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:tienda/Presentation/Services/sri_config_service.dart';
import 'package:tienda/Presentation/Services/sri_invoice_service.dart';
import 'package:tienda/Presentation/Services/sri_signer.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'SRI_ENABLED=false\n');
  });

  group('SRI unit tests', () {
    test(
      'T01 - clave de acceso tiene 49 caracteres y dígito verificador válido',
      () {
        final key = SriInvoiceService.generateAccessKey(
          ruc: '0999999999001',
          documentCode: '01',
          ambiente: 1,
          estab: '001',
          ptoEmi: '001',
          sequence: 123,
          date: DateTime(2026, 9, 28),
        );

        expect(key.length, 49);
        expect(SriInvoiceService.isValidAccessKey(key), isTrue);
      },
    );

    test(
      'T03 - validación mínima del comprador acepta RUC o cédula o consumidor final',
      () {
        expect(
          SriInvoiceService.validateCustomerData(
            ruc: '1790016919001',
            identificationType: 'ruc',
          ),
          isEmpty,
        );
        expect(
          SriInvoiceService.validateCustomerData(
            cedula: '1710034065',
            identificationType: 'cedula',
          ),
          isEmpty,
        );
        expect(
          SriInvoiceService.validateCustomerData(
            consumerFinal: true,
            total: 50,
          ),
          isEmpty,
        );
        expect(
          SriInvoiceService.validateCustomerData(
            consumerFinal: true,
            total: 50.01,
          ),
          'Consumidor final solo puede usarse hasta USD 50.',
        );
        expect(
          SriInvoiceService.validateCustomerData(),
          'Selecciona un tipo de identificación válido para el comprador.',
        );
      },
    );

    test(
      'T03 - admite pasaporte e identificación exterior sin validar cédula',
      () {
        expect(
          SriInvoiceService.validateCustomerData(
            identificationNumber: 'P-123/ABC',
            identificationType: 'pasaporte',
            total: 100,
          ),
          isEmpty,
        );
        expect(
          SriInvoiceService.validateCustomerData(
            identificationNumber: 'EXT-ID-X9',
            identificationType: '08',
            total: 100,
          ),
          isEmpty,
        );
        expect(
          SriInvoiceService.validateCustomerData(
            cedula: '1710034064',
            identificationType: 'cedula',
          ),
          'La cédula del comprador no es válida.',
        );
      },
    );

    test('el factory de firma no habilita plataformas no soportadas', () {
      final windows = SriSignerFactory.create(
        platformOverride: TargetPlatform.windows,
      );
      final android = SriSignerFactory.create(
        platformOverride: TargetPlatform.android,
      );
      final linux = SriSignerFactory.create(
        platformOverride: TargetPlatform.linux,
      );

      expect(windows.isSupported, isTrue);
      expect(android.isSupported, isTrue);
      expect(linux.isSupported, isFalse);
    });

    test('T04 - la bandera global apagada deshabilita el módulo', () {
      expect(SriConfigService.globalEnabled, isFalse);
      expect(SriInvoiceService.isGlobalEnabled, isFalse);
    });

    test(
      'T05 - el payload de factura respeta el store_id activo y el local configurado',
      () {
        final config = SriStoreConfig(
          id: 1,
          storeId: 7,
          sriEnabled: true,
          autoEmitOnCheckout: true,
          ambiente: 1,
          ruc: '0999999999001',
          razonSocial: 'Local Prueba',
          nombreComercial: 'Local Prueba',
          direccionMatriz: 'Av. Principal',
          codigoEstablecimiento: '001',
          puntoEmision: '002',
          tipoEmision: 'NORMAL',
          pathP12: '/tmp/cert.p12',
          p12Password: 'secret',
          facturaTipo: '01',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final payload = SriInvoiceService.buildInvoicePayload(
          storeId: 7,
          saleId: 55,
          total: 120.5,
          config: config,
          sale: {'date': '2026-09-28T12:00:00.000'},
          customer: {
            'name': 'Juan Pérez',
            'cedula': 'P-123/ABC',
            'identification_type': 'pasaporte',
          },
          items: [
            {'product_id': 1, 'quantity': 2, 'price': 60.25},
          ],
        );

        expect(payload['store_id'], 7);
        expect(payload['ruc'], '0999999999001');
        expect(payload['punto_emision'], '002');
        expect(payload['total'], 120.5);
        expect(payload['cliente_tipo_identificacion'], '06');
        expect(payload['cliente_id'], 'P-123/ABC');
        expect(payload['cliente_direccion'], '');
      },
    );

    test(
      'T06 - la configuración incompleta del local falla con control explícito',
      () {
        final config = SriStoreConfig(
          id: 0,
          storeId: 2,
          sriEnabled: true,
          autoEmitOnCheckout: false,
          ambiente: 1,
          ruc: '',
          razonSocial: '',
          nombreComercial: '',
          direccionMatriz: '',
          codigoEstablecimiento: '',
          puntoEmision: '',
          tipoEmision: 'NORMAL',
          pathP12: '',
          p12Password: '',
          facturaTipo: '01',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final error = SriConfigService.validateConfig(config);
        expect(error, isNotEmpty);
      },
    );

    test(
      'T08 - dos locales con RUC/estab/pto distintos no mezclan la configuración',
      () {
        final localA = SriStoreConfig(
          id: 1,
          storeId: 1,
          sriEnabled: true,
          autoEmitOnCheckout: true,
          ambiente: 1,
          ruc: '0999999999001',
          razonSocial: 'Local A',
          nombreComercial: 'Local A',
          direccionMatriz: 'Dir A',
          codigoEstablecimiento: '001',
          puntoEmision: '001',
          tipoEmision: 'NORMAL',
          pathP12: '/tmp/a.p12',
          p12Password: 'abc',
          facturaTipo: '01',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final localB = SriStoreConfig(
          id: 2,
          storeId: 2,
          sriEnabled: true,
          autoEmitOnCheckout: true,
          ambiente: 1,
          ruc: '0999999999002',
          razonSocial: 'Local B',
          nombreComercial: 'Local B',
          direccionMatriz: 'Dir B',
          codigoEstablecimiento: '001',
          puntoEmision: '002',
          tipoEmision: 'NORMAL',
          pathP12: '/tmp/b.p12',
          p12Password: 'def',
          facturaTipo: '01',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(localA.storeId, isNot(localB.storeId));
        expect(localA.ruc, isNot(localB.ruc));
        expect(localA.puntoEmision, isNot(localB.puntoEmision));
      },
    );

    test(
      'T09 - secuencias reales aisladas por local y punto de emisión',
      () async {
        sqfliteFfiInit();
        final testDatabase = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
        );
        await testDatabase.execute('''
        CREATE TABLE sri_sequences (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          store_id INTEGER NOT NULL,
          cod_doc TEXT NOT NULL,
          estab TEXT NOT NULL,
          pto_emi TEXT NOT NULL,
          current_value INTEGER NOT NULL DEFAULT 1,
          updated_at TEXT NOT NULL,
          UNIQUE(store_id, cod_doc, estab, pto_emi)
        )
      ''');
        DatabaseService.useDatabaseForTesting(testDatabase);

        try {
          expect(
            await SriInvoiceService.nextSequence(
              91,
              codDoc: '01',
              estab: '004',
              ptoEmi: '003',
            ),
            1,
          );
          expect(
            await SriInvoiceService.nextSequence(
              91,
              codDoc: '01',
              estab: '004',
              ptoEmi: '003',
            ),
            2,
          );
          expect(
            await SriInvoiceService.nextSequence(
              92,
              codDoc: '01',
              estab: '004',
              ptoEmi: '003',
            ),
            1,
          );
          expect(
            await SriInvoiceService.nextSequence(
              91,
              codDoc: '01',
              estab: '004',
              ptoEmi: '004',
            ),
            1,
          );

          final concurrent = await Future.wait([
            SriInvoiceService.nextSequence(
              91,
              codDoc: '01',
              estab: '004',
              ptoEmi: '003',
            ),
            SriInvoiceService.nextSequence(
              91,
              codDoc: '01',
              estab: '004',
              ptoEmi: '003',
            ),
          ]);
          expect(concurrent.toSet(), {3, 4});
        } finally {
          await testDatabase.close();
        }
      },
    );

    test('el historial de comprobantes queda aislado por store_id', () async {
      sqfliteFfiInit();
      final testDatabase = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
      );
      await testDatabase.execute('''
        CREATE TABLE electronic_invoices (
          id INTEGER PRIMARY KEY,
          store_id INTEGER NOT NULL,
          sale_id INTEGER NOT NULL,
          document_code TEXT,
          clave_acceso TEXT,
          estado TEXT,
          authorization_number TEXT,
          error_message TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
      await testDatabase.insert('electronic_invoices', {
        'id': 1,
        'store_id': 11,
        'sale_id': 101,
        'estado': 'ERROR',
        'created_at': '2026-10-01',
      });
      await testDatabase.insert('electronic_invoices', {
        'id': 2,
        'store_id': 12,
        'sale_id': 102,
        'estado': 'AUTORIZADO',
        'created_at': '2026-10-02',
      });
      DatabaseService.useDatabaseForTesting(testDatabase);

      try {
        final invoices = await SriInvoiceService.getInvoicesForStore(11);
        expect(invoices, hasLength(1));
        expect(invoices.single['sale_id'], 101);
        expect(invoices.single['estado'], 'ERROR');
      } finally {
        await testDatabase.close();
      }
    });

    test(
      'el CRM conserva tipos de identificación explícitos y ambiguos',
      () async {
        sqfliteFfiInit();
        final testDatabase = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
        );
        await testDatabase.execute('''
        CREATE TABLE clients (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT,
          email TEXT,
          notes TEXT,
          created_at TEXT NOT NULL,
          cedula TEXT,
          identification_type TEXT,
          address TEXT,
          apellidos TEXT,
          referencias TEXT,
          uid TEXT
        )
      ''');
        DatabaseService.useDatabaseForTesting(testDatabase);

        try {
          final foreignCustomerUid = await DatabaseService.createCustomer(
            name: 'Cliente extranjero',
            uid: 'foreign-customer',
            cedula: 'P-123/ABC',
            identificationType: 'pasaporte',
          );
          var customer = (await DatabaseService.rawQuery(
            'SELECT * FROM clients WHERE uid = ?',
            [foreignCustomerUid],
          )).single;
          expect(customer['identification_type'], 'pasaporte');
          expect(customer['cedula'], 'P-123/ABC');

          await DatabaseService.updateCustomer(
            id: (customer['id'] as num).toInt(),
            name: 'Cliente extranjero',
            uid: foreignCustomerUid,
            cedula: 'EXT-ID-X9',
            identificationType: 'identificacion exterior',
          );
          customer = (await DatabaseService.rawQuery(
            'SELECT * FROM clients WHERE uid = ?',
            [foreignCustomerUid],
          )).single;
          expect(customer['identification_type'], 'identificacion exterior');
          expect(customer['cedula'], 'EXT-ID-X9');

          await DatabaseService.createCustomer(
            name: 'Cliente sin clasificación',
            uid: 'unclassified-customer',
            cedula: '12345',
          );
          final unclassified = (await DatabaseService.rawQuery(
            'SELECT identification_type FROM clients WHERE uid = ?',
            ['unclassified-customer'],
          )).single;
          expect(unclassified['identification_type'], isNull);
        } finally {
          await testDatabase.close();
        }
      },
    );
  });
}
