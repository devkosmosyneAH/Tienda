class SupplierRucValidator {
  const SupplierRucValidator._();

  static String? validate(String? value) {
    final ruc = value?.trim() ?? '';
    if (ruc.isEmpty) return null;
    if (!RegExp(r'^\d{13}$').hasMatch(ruc)) {
      return 'El RUC debe contener 13 dígitos.';
    }

    final province = int.parse(ruc.substring(0, 2));
    if (province < 1 || province > 24 || int.parse(ruc.substring(10)) == 0) {
      return 'El RUC no es válido.';
    }

    final thirdDigit = int.parse(ruc[2]);
    final valid = switch (thirdDigit) {
      >= 0 && <= 5 => _validNaturalPersonRuc(ruc),
      6 => _validPublicEntityRuc(ruc),
      9 => _validPrivateEntityRuc(ruc),
      _ => false,
    };

    return valid ? null : 'El RUC no es válido.';
  }

  static bool _validNaturalPersonRuc(String ruc) {
    var sum = 0;
    for (var index = 0; index < 9; index++) {
      var value = int.parse(ruc[index]) * (index.isEven ? 2 : 1);
      if (value > 9) value -= 9;
      sum += value;
    }
    final checkDigit = (10 - sum % 10) % 10;
    return checkDigit == int.parse(ruc[9]);
  }

  static bool _validPublicEntityRuc(String ruc) {
    const weights = [3, 2, 7, 6, 5, 4, 3, 2];
    var sum = 0;
    for (var index = 0; index < weights.length; index++) {
      sum += int.parse(ruc[index]) * weights[index];
    }
    final remainder = sum % 11;
    final checkDigit = remainder == 0 ? 0 : 11 - remainder;
    return checkDigit < 10 && checkDigit == int.parse(ruc[8]);
  }

  static bool _validPrivateEntityRuc(String ruc) {
    const weights = [4, 3, 2, 7, 6, 5, 4, 3, 2];
    var sum = 0;
    for (var index = 0; index < weights.length; index++) {
      sum += int.parse(ruc[index]) * weights[index];
    }
    final remainder = sum % 11;
    final checkDigit = remainder == 0 ? 0 : 11 - remainder;
    return checkDigit < 10 && checkDigit == int.parse(ruc[9]);
  }
}
