import 'package:flutter/material.dart';
import 'package:tienda/Presentation/Model/user_model.dart';
import 'package:tienda/Presentation/Services/database_service.dart';

class UsersController extends ChangeNotifier {
  List<UserModel> _users = [];
  bool _loading = false;
  String? _error;

  List<UserModel> get users => _users;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadUsers() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final rows = await DatabaseService.rawQuery(
        'SELECT * FROM users ORDER BY created_at DESC',
        [],
      );
      _users = rows.map(UserModel.fromMap).toList();
    } catch (e) {
      _error = 'Error al cargar usuarios: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Crear un nuevo usuario. Devuelve null si fue exitoso, o un mensaje de error.
  Future<String?> createUser({
    required String email,
    required String password,
    required String name,
    required String lastname,
    required String role,
  }) async {
    try {
      // Verificar email único
      final existing = await DatabaseService.rawQuery(
        'SELECT id FROM users WHERE lower(email) = ?',
        [email.toLowerCase().trim()],
      );
      if (existing.isNotEmpty) {
        return 'Ya existe un usuario con ese correo.';
      }

      final uid = generateFirebaseId();
      await DatabaseService.rawInsert(
        '''INSERT INTO users (uid, email, password, name, lastname, role, is_active, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          uid,
          email.trim(),
          password,
          name.trim(),
          lastname.trim(),
          role,
          1,
          DateTime.now().toIso8601String(),
        ],
      );

      await loadUsers();
      return null;
    } catch (e) {
      return 'Error al crear usuario: $e';
    }
  }

  /// Actualizar rol y estado de un usuario.
  Future<String?> updateUser(UserModel user) async {
    try {
      await DatabaseService.rawQuery(
        '''UPDATE users SET name = ?, lastname = ?, role = ?, is_active = ?
           WHERE id = ?''',
        [user.name, user.lastname, user.role, user.isActive ? 1 : 0, user.id],
      );
      await loadUsers();
      return null;
    } catch (e) {
      return 'Error al actualizar usuario: $e';
    }
  }

  /// Cambiar contraseña de un usuario.
  Future<String?> changePassword(int userId, String newPassword) async {
    try {
      await DatabaseService.rawQuery(
        'UPDATE users SET password = ? WHERE id = ?',
        [newPassword, userId],
      );
      return null;
    } catch (e) {
      return 'Error al cambiar contraseña: $e';
    }
  }

  /// Activar / desactivar usuario (no se puede desactivar al único admin).
  Future<String?> toggleActive(UserModel user) async {
    if (user.role == 'admin' && user.isActive) {
      // Verificar que haya más de un admin activo antes de desactivar
      final admins = _users
          .where((u) => u.role == 'admin' && u.isActive)
          .toList();
      if (admins.length <= 1) {
        return 'No puedes desactivar al único administrador activo.';
      }
    }
    return updateUser(user.copyWith(isActive: !user.isActive));
  }

  /// Eliminar usuario (no se puede eliminar al único admin).
  Future<String?> deleteUser(UserModel user) async {
    if (user.role == 'admin') {
      final admins = _users.where((u) => u.role == 'admin').toList();
      if (admins.length <= 1) {
        return 'No puedes eliminar al único administrador del sistema.';
      }
    }
    try {
      await DatabaseService.rawQuery(
        'DELETE FROM users WHERE id = ?',
        [user.id],
      );
      await loadUsers();
      return null;
    } catch (e) {
      return 'Error al eliminar usuario: $e';
    }
  }
}
