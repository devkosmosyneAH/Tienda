enum PurchaseVatType { standard, zero, notObject, exempt }

class PurchaseLineInput {
  const PurchaseLineInput({
    this.productId,
    required this.quantity,
    required this.bonusQuantity,
    required this.unitCost,
    required this.discount,
    required this.vatType,
    required this.vatRate,
    this.bonusVatAmount = 0,
  });

  final int? productId;
  final int quantity;
  final int bonusQuantity;
  final double unitCost;
  final double discount;
  final PurchaseVatType vatType;
  final double vatRate;
  final double bonusVatAmount;
}

class PurchaseLineTotals {
  const PurchaseLineTotals({
    required this.productId,
    required this.quantity,
    required this.bonusQuantity,
    required this.unitCost,
    required this.vatType,
    required this.vatRate,
    required this.bonusVatAmount,
    required this.grossSubtotal,
    required this.discount,
    required this.taxableBase,
    required this.vatAmount,
    required this.total,
    required this.receivedQuantity,
    required this.effectiveUnitCost,
    required this.taxKey,
  });

  final int? productId;
  final int quantity;
  final int bonusQuantity;
  final double unitCost;
  final PurchaseVatType vatType;
  final double vatRate;
  final double bonusVatAmount;
  final double grossSubtotal;
  final double discount;
  final double taxableBase;
  final double vatAmount;
  final double total;
  final int receivedQuantity;
  final double effectiveUnitCost;
  final String taxKey;
}

class PurchaseTotals {
  const PurchaseTotals({
    required this.lines,
    required this.grossSubtotal,
    required this.discount,
    required this.subtotalByTax,
    required this.vatTotal,
    required this.total,
    required this.centTolerance,
  });

  final List<PurchaseLineTotals> lines;
  final double grossSubtotal;
  final double discount;
  final Map<String, double> subtotalByTax;
  final double vatTotal;
  final double total;
  final double centTolerance;

  static double money(double value) => (value * 100).roundToDouble() / 100;

  factory PurchaseTotals.calculate(
    Iterable<PurchaseLineInput> inputs, {
    double centTolerance = 0.01,
  }) {
    final lines = <PurchaseLineTotals>[];
    final subtotals = <String, double>{};
    var gross = 0.0;
    var discount = 0.0;
    var vat = 0.0;

    for (final input in inputs) {
      if (input.quantity < 0 || input.bonusQuantity < 0) {
        throw ArgumentError('Las cantidades no pueden ser negativas.');
      }
      if (!input.unitCost.isFinite || input.unitCost < 0) {
        throw ArgumentError('El costo unitario no es válido.');
      }
      if (!input.discount.isFinite || input.discount < 0) {
        throw ArgumentError('El descuento no es válido.');
      }
      if (!input.vatRate.isFinite || input.vatRate < 0) {
        throw ArgumentError('La tarifa de IVA no es válida.');
      }
      if (!input.bonusVatAmount.isFinite || input.bonusVatAmount < 0) {
        throw ArgumentError('El IVA de bonificación no es válido.');
      }

      final grossLine = money(input.quantity * input.unitCost);
      if (input.discount > grossLine) {
        throw ArgumentError('El descuento supera el subtotal de la línea.');
      }
      final lineDiscount = money(input.discount);
      final base = money(grossLine - lineDiscount);
      final taxKey = switch (input.vatType) {
        PurchaseVatType.standard => 'iva_${input.vatRate.toStringAsFixed(2)}',
        PurchaseVatType.zero => 'iva_0',
        PurchaseVatType.notObject => 'no_objeto',
        PurchaseVatType.exempt => 'exento',
      };
      final lineVat = input.vatType == PurchaseVatType.standard
          ? money(base * input.vatRate / 100 + input.bonusVatAmount)
          : 0.0;
      final received = input.quantity + input.bonusQuantity;
      final unitCost = received == 0 ? 0.0 : money(base / received);

      lines.add(
        PurchaseLineTotals(
          productId: input.productId,
          quantity: input.quantity,
          bonusQuantity: input.bonusQuantity,
          unitCost: input.unitCost,
          vatType: input.vatType,
          vatRate: input.vatRate,
          bonusVatAmount: money(input.bonusVatAmount),
          grossSubtotal: grossLine,
          discount: lineDiscount,
          taxableBase: base,
          vatAmount: lineVat,
          total: money(base + lineVat),
          receivedQuantity: received,
          effectiveUnitCost: unitCost,
          taxKey: taxKey,
        ),
      );
      gross += grossLine;
      discount += lineDiscount;
      vat += lineVat;
      subtotals[taxKey] = money((subtotals[taxKey] ?? 0) + base);
    }

    final roundedGross = money(gross);
    final roundedDiscount = money(discount);
    final roundedVat = money(vat);
    if (centTolerance < 0) throw ArgumentError('Tolerancia no válida.');
    return PurchaseTotals(
      lines: List.unmodifiable(lines),
      grossSubtotal: roundedGross,
      discount: roundedDiscount,
      subtotalByTax: Map.unmodifiable(subtotals),
      vatTotal: roundedVat,
      total: money(lines.fold<double>(0, (sum, line) => sum + line.total)),
      centTolerance: centTolerance,
    );
  }

  double weightedAverageCost({
    required int existingQuantity,
    required double existingUnitCost,
    required int receivedQuantity,
    required double receivedValue,
  }) {
    if (existingQuantity < 0 || receivedQuantity < 0) {
      throw ArgumentError('Las existencias no pueden ser negativas.');
    }
    if (existingQuantity + receivedQuantity == 0) return 0;
    final existingValue = existingQuantity * existingUnitCost;
    return money(
      (existingValue + receivedValue) / (existingQuantity + receivedQuantity),
    );
  }

  bool differsFromInvoice(double invoiceTotal) =>
      (money(invoiceTotal) - total).abs() > centTolerance;
}
