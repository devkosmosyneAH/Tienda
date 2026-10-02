import 'package:flutter_test/flutter_test.dart';
import 'package:tienda/Presentation/Controller/purchases_controller.dart';

void main() {
  test('genera un número de factura con formato 001-001-000000001', () {
    expect(PurchasesController.formatInvoiceNumber(1), '001-001-000000001');
    expect(PurchasesController.formatInvoiceNumber(12), '001-001-000000012');
    expect(
      PurchasesController.formatInvoiceNumber(123456),
      '001-001-000123456',
    );
  });

  test(
    'reinicia el valor cuando llega vacio y acepta una entrada ya válida',
    () {
      expect(PurchasesController.resolveInvoiceNumber(''), isNotEmpty);
      expect(
        PurchasesController.resolveInvoiceNumber('001-001-000000025'),
        '001-001-000000025',
      );
    },
  );
}
