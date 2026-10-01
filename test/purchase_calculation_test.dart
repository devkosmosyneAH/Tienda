import 'package:flutter_test/flutter_test.dart';
import 'package:tienda/Presentation/Model/purchase_calculation.dart';

void main() {
  group('PurchaseTotals', () {
    test('calculates mixed VAT buckets and rounds amounts centrally', () {
      final totals = PurchaseTotals.calculate([
        const PurchaseLineInput(
          quantity: 10,
          bonusQuantity: 0,
          unitCost: 10,
          discount: 5,
          vatType: PurchaseVatType.standard,
          vatRate: 15,
        ),
        const PurchaseLineInput(
          quantity: 5,
          bonusQuantity: 0,
          unitCost: 10,
          discount: 0,
          vatType: PurchaseVatType.zero,
          vatRate: 15,
        ),
        const PurchaseLineInput(
          quantity: 3,
          bonusQuantity: 0,
          unitCost: 10,
          discount: 0,
          vatType: PurchaseVatType.notObject,
          vatRate: 15,
        ),
        const PurchaseLineInput(
          quantity: 1,
          bonusQuantity: 0,
          unitCost: 10,
          discount: 0,
          vatType: PurchaseVatType.exempt,
          vatRate: 15,
        ),
      ]);

      expect(totals.subtotalByTax['iva_15.00'], 95);
      expect(totals.subtotalByTax['iva_0'], 50);
      expect(totals.subtotalByTax['no_objeto'], 30);
      expect(totals.subtotalByTax['exento'], 10);
      expect(totals.discount, 5);
      expect(totals.vatTotal, 14.25);
      expect(totals.total, 199.25);
      expect(totals.differsFromInvoice(199.26), isFalse);
      expect(totals.differsFromInvoice(199.27), isTrue);
    });

    test(
      'bonus units receive inventory and reduce the effective unit cost',
      () {
        final totals = PurchaseTotals.calculate([
          const PurchaseLineInput(
            quantity: 5,
            bonusQuantity: 1,
            unitCost: 10,
            discount: 0,
            vatType: PurchaseVatType.standard,
            vatRate: 15,
          ),
        ]);
        final line = totals.lines.single;

        expect(line.receivedQuantity, 6);
        expect(line.total, 57.5);
        expect(line.effectiveUnitCost, 8.33);
        expect(
          totals.weightedAverageCost(
            existingQuantity: 4,
            existingUnitCost: 7,
            receivedQuantity: line.receivedQuantity,
            receivedValue: line.taxableBase,
          ),
          7.8,
        );
      },
    );

    test('uses the VAT explicitly stated for the bonus units', () {
      final totals = PurchaseTotals.calculate([
        const PurchaseLineInput(
          quantity: 5,
          bonusQuantity: 1,
          unitCost: 10,
          discount: 0,
          vatType: PurchaseVatType.standard,
          vatRate: 15,
          bonusVatAmount: 1.5,
        ),
      ]);

      expect(totals.vatTotal, 9);
      expect(totals.total, 59);
      expect(totals.lines.single.effectiveUnitCost, 8.33);
    });

    test('rejects discounts larger than the line base', () {
      expect(
        () => PurchaseTotals.calculate([
          const PurchaseLineInput(
            quantity: 1,
            bonusQuantity: 0,
            unitCost: 10,
            discount: 11,
            vatType: PurchaseVatType.zero,
            vatRate: 15,
          ),
        ]),
        throwsArgumentError,
      );
    });
  });
}
