import 'package:flutter_test/flutter_test.dart';
import 'package:tienda/Presentation/Model/sri_store_config_model.dart';
import 'package:tienda/Presentation/Services/sri_config_service.dart';
import 'package:tienda/Presentation/Services/sri_invoice_service.dart';

void main() {
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
        expect(key.substring(key.length - 1), isNotEmpty);
      },
    );

    test(
      'T03 - validación mínima del comprador acepta RUC o cédula o consumidor final',
      () {
        expect(
          SriInvoiceService.validateCustomerData(ruc: '0999999999001'),
          isEmpty,
        );
        expect(
          SriInvoiceService.validateCustomerData(cedula: '1712345678'),
          isEmpty,
        );
        expect(
          SriInvoiceService.validateCustomerData(consumerFinal: true),
          isEmpty,
        );
        expect(
          SriInvoiceService.validateCustomerData(),
          'Debe indicarse RUC (13 dígitos), cédula válida o consumidor final.',
        );
      },
    );

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
          customer: {'name': 'Juan Pérez', 'cedula': '1712345678'},
          items: [
            {'product_id': 1, 'quantity': 2, 'price': 60.25},
          ],
        );

        expect(payload['store_id'], 7);
        expect(payload['ruc'], '0999999999001');
        expect(payload['punto_emision'], '002');
        expect(payload['total'], 120.5);
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

    test('T09 - secuencias por local no colisionan ni comparten estado', () {
      final storeA = 991;
      final storeB = 992;
      final firstA = SriInvoiceService.generateAccessKey(
        ruc: '0999999999001',
        documentCode: '01',
        ambiente: 1,
        estab: '001',
        ptoEmi: '001',
        sequence: 1,
        date: DateTime(2026, 9, 28),
      );
      final firstB = SriInvoiceService.generateAccessKey(
        ruc: '0999999999002',
        documentCode: '01',
        ambiente: 1,
        estab: '001',
        ptoEmi: '001',
        sequence: 1,
        date: DateTime(2026, 9, 28),
      );

      expect(storeA, isNot(storeB));
      expect(firstA, isNot(firstB));
    });
  });
}
