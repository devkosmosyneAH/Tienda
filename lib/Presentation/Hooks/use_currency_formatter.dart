import 'package:intl/intl.dart';

class CurrencyFormatter {
  /// Formatea un número como moneda
  static String formatCurrency(double amount, {String? currency = '\$'}) {
    final formatter = NumberFormat.simpleCurrency(
      locale: 'es_ES',
      name: currency,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Formatea un número como moneda sin símbolo
  static String formatCurrencyNoSymbol(double amount) {
    final formatter = NumberFormat('###,##0.00', 'es_ES');
    return formatter.format(amount);
  }

  /// Parsea una cadena a double
  static double? parseCurrency(String value) {
    try {
      return double.parse(value.replaceAll(',', '.').replaceAll('\$', ''));
    } catch (_) {
      return null;
    }
  }

  /// Formatea un número como porcentaje
  static String formatPercentage(double percentage) {
    final formatter = NumberFormat('###,##0.00%', 'es_ES');
    return formatter.format(percentage / 100);
  }

  /// Redondea un número a 2 decimales
  static double roundToTwoDecimals(double value) {
    return (value * 100).round() / 100;
  }

  /// Calcula el IVA
  static double calculateTax(double amount, {double taxRate = 0.19}) {
    return roundToTwoDecimals(amount * taxRate);
  }

  /// Calcula el total con IVA
  static double calculateTotalWithTax(double amount, {double taxRate = 0.19}) {
    return roundToTwoDecimals(amount + calculateTax(amount, taxRate: taxRate));
  }

  /// Calcula descuento
  static double calculateDiscount(double amount, double discountPercent) {
    return roundToTwoDecimals(amount * (discountPercent / 100));
  }

  /// Calcula total con descuento
  static double calculateTotalWithDiscount(
    double amount,
    double discountPercent,
  ) {
    return roundToTwoDecimals(amount - calculateDiscount(amount, discountPercent));
  }

  /// Verifica si es un número válido
  static bool isValidCurrency(String value) {
    return double.tryParse(value.replaceAll(',', '.')) != null;
  }

  /// Obtiene el símbolo de moneda por país
  static String getCurrencySymbol(String countryCode) {
    const currencySymbols = {
      'CO': '\$', // Colombia
      'US': '\$', // USA
      'MX': '\$', // México
      'AR': '\$', // Argentina
      'CL': '\$', // Chile
      'ES': '€', // España
      'GB': '£', // Reino Unido
    };
    return currencySymbols[countryCode] ?? '\$';
  }
}
