import 'package:flutter_test/flutter_test.dart';
import 'package:tienda/Presentation/Utils/supplier_ruc_validator.dart';
import 'package:tienda/Presentation/Services/sri_invoice_service.dart';

void main() {
  group('SupplierRucValidator', () {
    test('accepts a valid Ecuadorian private-company RUC', () {
      expect(SupplierRucValidator.validate('1790016919001'), isNull);
    });

    test('accepts valid natural-person and public-entity RUCs', () {
      expect(SupplierRucValidator.validate('1710034065001'), isNull);
      expect(SupplierRucValidator.validate('1760001550001'), isNull);
    });

    test('validates cedula with Ecuadorian check digit', () {
      expect(SupplierRucValidator.validateCedula('1710034065'), isNull);
      expect(SupplierRucValidator.validateCedula('1710034064'), isNotNull);
      expect(SupplierRucValidator.validateCedula('0010034065'), isNotNull);
    });

    test('requires identification on the supplier form', () {
      expect(
        SupplierRucValidator.validateIdentification(value: ' ', type: 'ruc'),
        'La identificación es obligatoria.',
      );
    });

    test('checks invoice number, date, and supplier RUC inside access key', () {
      final key = SriInvoiceService.generateAccessKey(
        ruc: '1790016919001',
        documentCode: '01',
        ambiente: 1,
        estab: '001',
        ptoEmi: '001',
        sequence: 1,
        date: DateTime(2026, 10, 1),
      );
      expect(
        SupplierRucValidator.validateAccessKeyForInvoice(
          accessKey: key,
          invoiceNumber: '001-001-000000001',
          issueDate: DateTime(2026, 10, 1),
          supplierRuc: '1790016919001',
        ),
        isNull,
      );
      expect(
        SupplierRucValidator.validateAccessKeyForInvoice(
          accessKey: key,
          invoiceNumber: '001-001-000000002',
          issueDate: DateTime(2026, 10, 1),
          supplierRuc: '1790016919001',
        ),
        isNotNull,
      );
    });

    test('rejects invalid length, province, and check digit', () {
      expect(SupplierRucValidator.validate('179001691900'), isNotNull);
      expect(SupplierRucValidator.validate('0090016919001'), isNotNull);
      expect(SupplierRucValidator.validate('1790016918001'), isNotNull);
    });

    test('allows an empty optional RUC', () {
      expect(SupplierRucValidator.validate('  '), isNull);
    });
  });
}
