class SupplierRucValidator {
  const SupplierRucValidator._();

  static String? validate(String? value) {
    final ruc = value?.trim() ?? '';
    if (ruc.isEmpty) return null;
    if (!RegExp(r'^\d{13}$').hasMatch(ruc)) {
      return 'El RUC debe contener 13 dígitos.';
    }
    return isValidRuc(ruc) ? null : 'El RUC no es válido.';
  }

  static String? validateCedula(String? value) {
    final cedula = value?.trim() ?? '';
    if (!RegExp(r'^\d{10}$').hasMatch(cedula)) {
      return 'La cédula debe contener 10 dígitos.';
    }
    return isValidCedula(cedula) ? null : 'La cédula no es válida.';
  }

  static String? validateIdentification({
    required String? value,
    required String type,
  }) {
    if (value?.trim().isNotEmpty != true) {
      return 'La identificación es obligatoria.';
    }
    return type.toLowerCase() == 'cedula'
        ? validateCedula(value)
        : validate(value);
  }

  static bool isValidCedula(String value) {
    if (!RegExp(r'^\d{10}$').hasMatch(value)) return false;
    final province = int.parse(value.substring(0, 2));
    if (province < 1 || province > 24 || int.parse(value[2]) > 5) {
      return false;
    }
    return _cedulaCheckDigit(value.substring(0, 10));
  }

  static bool isValidRuc(String value) {
    if (!RegExp(r'^\d{13}$').hasMatch(value)) return false;
    final province = int.parse(value.substring(0, 2));
    final thirdDigit = int.parse(value[2]);
    if (province < 1 || province > 24 || int.parse(value.substring(10)) == 0) {
      return false;
    }

    return switch (thirdDigit) {
      >= 0 && <= 5 =>
        _cedulaCheckDigit(value.substring(0, 10)) &&
            int.parse(value.substring(10)) > 0,
      6 => _publicEntityCheckDigit(value),
      9 => _privateEntityCheckDigit(value),
      _ => false,
    };
  }

  static String? validateAccessKey(String? value) {
    final key = value?.trim() ?? '';
    if (!RegExp(r'^\d{49}$').hasMatch(key)) {
      return 'La clave de acceso debe contener 49 dígitos.';
    }
    final expected = _modulo11(key.substring(0, 48));
    return expected == int.parse(key[48])
        ? null
        : 'El dígito verificador de la clave de acceso no es válido.';
  }

  static String? validateAccessKeyForInvoice({
    required String accessKey,
    required String invoiceNumber,
    required DateTime issueDate,
    String? supplierRuc,
  }) {
    final keyError = validateAccessKey(accessKey);
    if (keyError != null) return keyError;
    final key = accessKey.trim();
    final expectedDate =
        '${issueDate.day.toString().padLeft(2, '0')}'
        '${issueDate.month.toString().padLeft(2, '0')}'
        '${issueDate.year}';
    if (key.substring(0, 8) != expectedDate) {
      return 'La fecha de la clave de acceso no coincide con la emisión.';
    }
    final keyInvoice =
        '${key.substring(24, 27)}-${key.substring(27, 30)}-${key.substring(30, 39)}';
    if (keyInvoice != invoiceNumber.trim()) {
      return 'El número secuencial no coincide con la clave de acceso.';
    }
    if (supplierRuc != null &&
        supplierRuc.trim().isNotEmpty &&
        key.substring(10, 23) != supplierRuc.trim()) {
      return 'El RUC de la clave de acceso no coincide con el proveedor.';
    }
    return null;
  }

  static bool _cedulaCheckDigit(String cedula) {
    var sum = 0;
    for (var index = 0; index < 9; index++) {
      var value = int.parse(cedula[index]) * (index.isEven ? 2 : 1);
      if (value > 9) value -= 9;
      sum += value;
    }
    final checkDigit = (10 - sum % 10) % 10;
    return checkDigit == int.parse(cedula[9]);
  }

  static bool _publicEntityCheckDigit(String ruc) {
    const weights = [3, 2, 7, 6, 5, 4, 3, 2];
    var sum = 0;
    for (var index = 0; index < weights.length; index++) {
      sum += int.parse(ruc[index]) * weights[index];
    }
    final remainder = sum % 11;
    final checkDigit = remainder == 0 ? 0 : 11 - remainder;
    return checkDigit < 10 &&
        checkDigit == int.parse(ruc[8]) &&
        int.parse(ruc.substring(9)) > 0;
  }

  static bool _privateEntityCheckDigit(String ruc) {
    const weights = [4, 3, 2, 7, 6, 5, 4, 3, 2];
    var sum = 0;
    for (var index = 0; index < weights.length; index++) {
      sum += int.parse(ruc[index]) * weights[index];
    }
    final remainder = sum % 11;
    final checkDigit = remainder == 0 ? 0 : 11 - remainder;
    return checkDigit < 10 &&
        checkDigit == int.parse(ruc[9]) &&
        int.parse(ruc.substring(10)) > 0;
  }

  static int _modulo11(String value) {
    var factor = 2;
    var total = 0;
    for (var index = value.length - 1; index >= 0; index--) {
      total += int.parse(value[index]) * factor;
      factor = factor == 7 ? 2 : factor + 1;
    }
    final result = 11 - total % 11;
    return result == 11 ? 0 : (result == 10 ? 1 : result);
  }
}
