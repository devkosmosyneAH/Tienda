import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Servicio para manejar la persistencia de sesión del usuario
class SessionService {
  static const String _sessionKey = 'user_session';
  static const String _isLoggedInKey = 'is_logged_in';

  /// Guardar sesión del usuario
  static Future<bool> saveUserSession(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Guardar datos del usuario como JSON
      final userJson = jsonEncode(userData);
      await prefs.setString(_sessionKey, userJson);

      // Marcar como loggeado
      await prefs.setBool(_isLoggedInKey, true);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Obtener sesión del usuario actual
  static Future<Map<String, dynamic>?> getCurrentUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Verificar si está loggeado
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

      if (!isLoggedIn) {
        return null;
      }

      // Obtener datos del usuario
      final userJson = prefs.getString(_sessionKey);

      if (userJson != null) {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        return userData;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Verificar si hay una sesión activa
  static Future<bool> isUserLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

      if (isLoggedIn) {
        // Verificar que también existan los datos
        final userJson = prefs.getString(_sessionKey);
        return userJson != null;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Cerrar sesión del usuario
  static Future<bool> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Limpiar datos de sesión
      await prefs.remove(_sessionKey);
      await prefs.setBool(_isLoggedInKey, false);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Actualizar datos del usuario en sesión
  static Future<bool> updateUserSession(
    Map<String, dynamic> updatedData,
  ) async {
    try {
      // Verificar que hay sesión activa
      final isLoggedIn = await isUserLoggedIn();
      if (!isLoggedIn) {
        return false;
      }

      // Guardar datos actualizados
      return await saveUserSession(updatedData);
    } catch (e) {
      return false;
    }
  }

  /// Obtener información específica del usuario actual
  static Future<String?> getCurrentUserId() async {
    final session = await getCurrentUserSession();
    return session?['uid'];
  }

  static Future<String?> getCurrentUserEmail() async {
    final session = await getCurrentUserSession();
    return session?['email'];
  }

  static Future<String?> getCurrentUserName() async {
    final session = await getCurrentUserSession();
    return session?['name'];
  }

  static Future<String?> getCurrentUserRole() async {
    final session = await getCurrentUserSession();
    return session?['role'];
  }

  static Future<String?> getCurrentUserPermission() async {
    final session = await getCurrentUserSession();
    return session?['permission'];
  }

  /// Método para debug - mostrar información de sesión
  static Future<void> debugSessionInfo() async {
    try {
      final isLoggedIn = await isUserLoggedIn();

      if (isLoggedIn) {
        await getCurrentUserSession();
      }
    } catch (e) {
      return;
    }
  }
}
