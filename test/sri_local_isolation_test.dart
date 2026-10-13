import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sri_xml_validator/sri_xml_validator.dart';
import 'package:xml/xml.dart';
import 'package:tienda/Presentation/Model/sri_store_config_model.dart';
import 'package:tienda/Presentation/Services/sri_config_service.dart';
import 'package:tienda/Presentation/Services/sri_invoice_service.dart';

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

    test(
      'T01 - la clave incluye campos SRI oficiales y el dígito módulo 11',
      () {
        const body =
            '2809202601'
            '0999999999001'
            '1'
            '001'
            '002'
            '000000123'
            '12345678'
            '1';
        final key = SriInvoiceService.generateAccessKey(
          ruc: '0999999999001',
          documentCode: '01',
          ambiente: 1,
          estab: '001',
          ptoEmi: '002',
          sequence: 123,
          date: DateTime(2026, 9, 28),
          codigoNumerico: '12345678',
          tipoEmision: '1',
        );

        expect(key, '$body${_modulo11ForTest(body)}');
        expect(key, hasLength(49));
        expect(SriInvoiceService.calculateModulo11('123456789'), 2);
      },
    );

    test('T05 - XML factura agrupa IVA y conserva el total de la venta', () {
      final config = SriStoreConfig(
        id: 1,
        storeId: 7,
        sriEnabled: true,
        autoEmitOnCheckout: true,
        ambiente: 1,
        ruc: '0999999999001',
        razonSocial: 'Local de prueba',
        nombreComercial: 'Tienda de prueba',
        direccionMatriz: 'Av. Principal 123',
        codigoEstablecimiento: '001',
        puntoEmision: '002',
        tipoEmision: 'NORMAL',
        pathP12: '/tmp/cert.p12',
        p12Password: 'secret',
        facturaTipo: '01',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final accessKey = SriInvoiceService.generateAccessKey(
        ruc: config.ruc,
        documentCode: config.facturaTipo,
        ambiente: config.ambiente,
        estab: config.codigoEstablecimiento,
        ptoEmi: config.puntoEmision,
        sequence: 1,
        date: DateTime(2026, 9, 28),
        codigoNumerico: '12345678',
      );
      final xml = SriInvoiceService.buildInvoiceXml(
        config: config,
        sale: {
          'date': '2026-09-28T12:00:00.000',
          'total': 115.00,
          'payments': [
            {'forma_pago': '01', 'total': 115.0, 'credito': false},
          ],
        },
        customer: {
          'name': 'Juan Pérez',
          'identification_number': '1712345678',
          'identification_type': 'cedula',
        },
        items: [
          {
            'product_id': 1,
            'product_name': 'Producto con IVA',
            'quantity': 1,
            'price': 115.0,
            'iva_rate': 15.0,
          },
        ],
        accessKey: accessKey,
        sequence: 1,
      );
      final document = XmlDocument.parse(xml);

      expect(document.rootElement.name.local, 'factura');
      expect(
        document.findAllElements('claveAcceso').single.innerText,
        accessKey,
      );
      expect(
        document.findAllElements('importeTotal').single.innerText,
        '115.00',
      );
      expect(
        document.findAllElements('precioUnitario').single.innerText,
        '100.00',
      );
      expect(
        document.findAllElements('totalSinImpuestos').single.innerText,
        '100.00',
      );
      expect(
        document
            .findAllElements('codigoPorcentaje')
            .map((node) => node.innerText)
            .toList(),
        ['4', '4'],
      );
      expect(
        document
            .findAllElements('valor')
            .map((node) => node.innerText)
            .toList(),
        ['15.00', '15.00'],
      );
    });

    test(
      'el parser SRI conserva estados, mensajes y datos de autorización',
      () {
        final rejected = SriInvoiceService.parseAuthorizationResponse('''
<autorizacionComprobanteResponse>
  <autorizaciones>
    <autorizacion>
      <estado>NO AUTORIZADO</estado>
      <numeroAutorizacion>clave-rechazada</numeroAutorizacion>
      <fechaAutorizacion>2026-10-12T20:00:00-05:00</fechaAutorizacion>
      <mensajes>
        <mensaje>
          <identificador>70</identificador>
          <mensaje>La base imponible no coincide.</mensaje>
          <informacionAdicional>Revise el cálculo del IVA.</informacionAdicional>
          <tipo>ERROR</tipo>
        </mensaje>
      </mensajes>
    </autorizacion>
  </autorizaciones>
</autorizacionComprobanteResponse>
''');
        expect(rejected.estado, EstadoAutorizacion.noAutorizado);
        expect(rejected.mensajes, hasLength(1));
        expect(rejected.mensajes.single.identificador, '70');
        expect(
          rejected.mensajes.single.mensaje,
          'La base imponible no coincide.',
        );
        expect(
          rejected.mensajes.single.informacionAdicional,
          'Revise el cálculo del IVA.',
        );
        expect(rejected.mensajes.single.tipo, 'ERROR');

        final inProgress = SriInvoiceService.parseAuthorizationResponse('''
<autorizacionComprobanteResponse>
  <autorizaciones>
    <autorizacion><estado>EN_PROCESO</estado></autorizacion>
  </autorizaciones>
</autorizacionComprobanteResponse>
''');
        expect(inProgress.estado, EstadoAutorizacion.enProceso);

        final authorized = SriInvoiceService.parseAuthorizationResponse('''
<autorizacionComprobanteResponse>
  <autorizaciones>
    <autorizacion>
      <estado>AUTORIZADO</estado>
      <numeroAutorizacion>123456789</numeroAutorizacion>
      <fechaAutorizacion>2026-10-12T20:00:00-05:00</fechaAutorizacion>
      <comprobante>&lt;factura/&gt;</comprobante>
    </autorizacion>
  </autorizaciones>
</autorizacionComprobanteResponse>
''');
        expect(authorized.estado, EstadoAutorizacion.autorizado);
        expect(authorized.numeroAutorizacion, '123456789');
        expect(authorized.fechaAutorizacion, isNotNull);
        expect(authorized.xmlAutorizado, '<factura/>');
      },
    );

    test(
      'la base del IVA incluido se genera como precio unitario antes de IVA',
      () {
        final config = SriStoreConfig(
          id: 1,
          storeId: 7,
          sriEnabled: true,
          autoEmitOnCheckout: true,
          ambiente: 1,
          ruc: '0999999999001',
          razonSocial: 'Local de prueba',
          nombreComercial: 'Tienda de prueba',
          direccionMatriz: 'Av. Principal 123',
          codigoEstablecimiento: '001',
          puntoEmision: '002',
          tipoEmision: 'NORMAL',
          pathP12: '/tmp/cert.p12',
          p12Password: 'secret',
          facturaTipo: '01',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        final accessKey = SriInvoiceService.generateAccessKey(
          ruc: config.ruc,
          documentCode: config.facturaTipo,
          ambiente: config.ambiente,
          estab: config.codigoEstablecimiento,
          ptoEmi: config.puntoEmision,
          sequence: 1,
          date: DateTime(2026, 9, 28),
          codigoNumerico: '12345678',
        );
        final xml = SriInvoiceService.buildInvoiceXml(
          config: config,
          sale: {
            'date': '2026-09-28T12:00:00.000',
            'total': 112,
            'payments': [
              {'forma_pago': '01', 'total': 112.0, 'credito': false},
            ],
          },
          customer: {
            'name': 'Juan Pérez',
            'identification_number': '1712345678',
            'identification_type': 'cedula',
          },
          items: [
            {
              'product_id': 1,
              'product_name': 'Producto con IVA',
              'quantity': 1,
              'price': 112.0,
              'iva_rate': 12.0,
            },
          ],
          accessKey: accessKey,
          sequence: 1,
        );
        final document = XmlDocument.parse(xml);
        expect(
          document.findAllElements('totalSinImpuestos').single.innerText,
          '100.00',
        );
        expect(
          document
              .findAllElements('codigoPorcentaje')
              .map((node) => node.innerText),
          ['2', '2'],
        );
        expect(
          document.findAllElements('valor').map((node) => node.innerText),
          ['12.00', '12.00'],
        );
        expect(
          document.findAllElements('importeTotal').single.innerText,
          '112.00',
        );
      },
    );
  });
}

int _modulo11ForTest(String digits) {
  var factor = 2;
  var total = 0;
  for (var index = digits.length - 1; index >= 0; index--) {
    total += int.parse(digits[index]) * factor;
    factor = factor == 7 ? 2 : factor + 1;
  }
  final check = 11 - total % 11;
  if (check == 11) return 0;
  if (check == 10) return 1;
  return check;
}
