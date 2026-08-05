import 'package:intl/intl.dart';

class DateFormatter {
  /// Formatea una fecha como "dd/MM/yyyy"
  static String formatDate(DateTime date) {
    final formatter = DateFormat('dd/MM/yyyy', 'es_ES');
    return formatter.format(date);
  }

  /// Formatea una fecha con hora como "dd/MM/yyyy HH:mm"
  static String formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm', 'es_ES');
    return formatter.format(dateTime);
  }

  /// Formatea solo la hora como "HH:mm"
  static String formatTime(DateTime dateTime) {
    final formatter = DateFormat('HH:mm', 'es_ES');
    return formatter.format(dateTime);
  }

  /// Formatea una fecha en formato completo
  static String formatFullDate(DateTime date) {
    final formatter = DateFormat('EEEE, dd MMMM yyyy', 'es_ES');
    return formatter.format(date);
  }

  /// Formatea mes y año
  static String formatMonthYear(DateTime date) {
    final formatter = DateFormat('MMMM yyyy', 'es_ES');
    return formatter.format(date);
  }

  /// Obtiene la diferencia en días
  static int daysDifference(DateTime from, DateTime to) {
    return to.difference(from).inDays;
  }

  /// Obtiene la diferencia legible
  static String getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Hace ${difference.inSeconds}s';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays}d';
    } else if (difference.inDays < 30) {
      return 'Hace ${(difference.inDays / 7).floor()}s';
    } else {
      return formatDate(dateTime);
    }
  }

  /// Verifica si una fecha es hoy
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Verifica si una fecha es ayer
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  /// Obtiene el primer día del mes
  static DateTime firstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// Obtiene el último día del mes
  static DateTime lastDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  /// Formatea el rango de fechas
  static String formatDateRange(DateTime from, DateTime to) {
    return '${formatDate(from)} - ${formatDate(to)}';
  }

  /// Parsea una cadena a DateTime
  static DateTime? parseDate(String dateString) {
    try {
      return DateFormat('dd/MM/yyyy', 'es_ES').parse(dateString);
    } catch (_) {
      return null;
    }
  }

  /// Obtiene nombre del día
  static String getDayName(DateTime date) {
    final formatter = DateFormat('EEEE', 'es_ES');
    return formatter.format(date);
  }

  /// Obtiene nombre del mes
  static String getMonthName(int month) {
    final date = DateTime(2024, month);
    final formatter = DateFormat('MMMM', 'es_ES');
    return formatter.format(date);
  }
}
