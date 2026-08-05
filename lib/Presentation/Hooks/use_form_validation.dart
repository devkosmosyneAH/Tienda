import 'package:flutter/material.dart';

class ValidationError {
  final String field;
  final String message;

  ValidationError({required this.field, required this.message});
}

class FormValidator {
  /// Valida un email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'El email es requerido';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value)) {
      return 'Email inválido';
    }
    return null;
  }

  /// Valida un teléfono
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'El teléfono es requerido';
    }
    if (value.length < 7) {
      return 'El teléfono debe tener al menos 7 dígitos';
    }
    return null;
  }

  /// Valida un nombre
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'El nombre es requerido';
    }
    if (value.length < 2) {
      return 'El nombre debe tener al menos 2 caracteres';
    }
    return null;
  }

  /// Valida un precio
  static String? validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'El precio es requerido';
    }
    final price = double.tryParse(value);
    if (price == null || price <= 0) {
      return 'El precio debe ser un número positivo';
    }
    return null;
  }

  /// Valida una cantidad
  static String? validateQuantity(String? value) {
    if (value == null || value.isEmpty) {
      return 'La cantidad es requerida';
    }
    final quantity = int.tryParse(value);
    if (quantity == null || quantity <= 0) {
      return 'La cantidad debe ser un número positivo';
    }
    return null;
  }

  /// Valida un código de barras
  static String? validateBarcode(String? value) {
    if (value == null || value.isEmpty) {
      return 'El código de barras es requerido';
    }
    if (value.length < 8) {
      return 'El código de barras debe tener al menos 8 caracteres';
    }
    return null;
  }

  /// Valida un campo requerido
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName es requerido';
    }
    return null;
  }

  /// Validación personalizada
  static String? validate(
    String? value, {
    required String fieldName,
    bool required = false,
    int? minLength,
    int? maxLength,
    Pattern? pattern,
  }) {
    if (required && (value == null || value.isEmpty)) {
      return '$fieldName es requerido';
    }

    if (value != null && value.isNotEmpty) {
      if (minLength != null && value.length < minLength) {
        return '$fieldName debe tener al menos $minLength caracteres';
      }
      if (maxLength != null && value.length > maxLength) {
        return '$fieldName no debe exceder $maxLength caracteres';
      }
      if (pattern != null && !RegExp(pattern.toString()).hasMatch(value)) {
        return '$fieldName tiene un formato inválido';
      }
    }

    return null;
  }
}

/// Hook para usar validador de forma
class FormValidatorHook {
  final formKey = GlobalKey<FormState>();
  final Map<String, String?> errors = {};

  bool validate() {
    if (formKey.currentState?.validate() ?? false) {
      errors.clear();
      return true;
    }
    return false;
  }

  void setError(String field, String? error) {
    if (error == null) {
      errors.remove(field);
    } else {
      errors[field] = error;
    }
  }

  String? getError(String field) => errors[field];

  void clearErrors() => errors.clear();

  void reset() {
    formKey.currentState?.reset();
    errors.clear();
  }
}
