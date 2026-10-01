import 'package:flutter_test/flutter_test.dart';
import 'package:tienda/Presentation/Utils/supplier_ruc_validator.dart';

void main() {
  group('SupplierRucValidator', () {
    test('accepts a valid Ecuadorian private-company RUC', () {
      expect(SupplierRucValidator.validate('1790016919001'), isNull);
    });

    test('accepts valid natural-person and public-entity RUCs', () {
      expect(SupplierRucValidator.validate('1710034065001'), isNull);
      expect(SupplierRucValidator.validate('1760001550001'), isNull);
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
