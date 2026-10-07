import 'package:flutter/material.dart';
import 'package:tienda/Presentation/Model/user_model.dart';
import 'package:tienda/Presentation/Repository/user_repository.dart';
import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:tienda/Presentation/Services/audit_service.dart';

class UsersController extends ChangeNotifier {
  UsersController({UserRepository? repository})
      : _repository = repository ?? const DatabaseUserRepository();

  final UserRepository _repository;
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
      _users = await _repository.loadUsers();
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
      if (await _repository.emailExists(email)) {
        return 'Ya existe un usuario con ese correo.';
      }

      final uid = generateFirebaseId();
      final userId = await _repository.createUser(
        email: email,
        password: password,
        name: name,
        lastname: lastname,
        role: role,
        uid: uid,
      );
      await AuditService.log(
        action: AuditAction.createUser, module: 'Users', page: 'UsersView',
        entity: 'user', entityId: userId,
        newData: {'email': email.trim(), 'name': name.trim(),
          'lastname': lastname.trim(), 'role': role, 'is_active': 1},
        controller: 'UsersController',
      );

      await loadUsers();
      return null;
    } catch (e) {
      return 'Error al crear usuario: $e';
    }
  }

  /// Actualizar rol y estado de un usuario.
  Future<String?> updateUser(UserModel user) async {
    final userId = user.id;
    if (userId == null) {
      return 'No se puede actualizar un usuario sin identificador.';
    }

    try {
      final before = (await _repository.getUserById(userId))?.toMap();
      await _repository.updateUser(user);
      final after = await _repository.getUserById(userId);
      await AuditService.log(
        action: before != null && before['role'] != user.role
            ? AuditAction.changeRole : AuditAction.updateUser,
        module: 'Users', page: 'UsersView', entity: 'user', entityId: userId,
        oldData: before,
        newData: after?.toMap(),
        controller: 'UsersController',
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
      await _repository.changePassword(userId, newPassword);
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
    final userId = user.id;
    if (userId == null) {
      return 'No se puede eliminar un usuario sin identificador.';
    }

    if (user.role == 'admin') {
      final admins = _users.where((u) => u.role == 'admin').toList();
      if (admins.length <= 1) {
        return 'No puedes eliminar al único administrador del sistema.';
      }
    }
    try {
      final before = (await _repository.getUserById(userId))?.toMap();
      await _repository.deleteUser(userId);
      await AuditService.log(
        action: AuditAction.deleteUser, module: 'Users', page: 'UsersView',
        entity: 'user', entityId: userId,
        oldData: before,
        controller: 'UsersController',
      );
      await loadUsers();
      return null;
    } catch (e) {
      return 'Error al eliminar usuario: $e';
    }
  }
}
