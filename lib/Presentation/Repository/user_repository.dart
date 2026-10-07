import 'package:tienda/Presentation/Model/user_model.dart';
import 'package:tienda/Presentation/Services/database_service.dart';

abstract class UserRepository {
  Future<List<UserModel>> loadUsers();

  Future<bool> emailExists(String email);

  Future<UserModel?> getUserById(int userId);

  Future<int> createUser({
    required String email,
    required String password,
    required String name,
    required String lastname,
    required String role,
    String? uid,
    bool isActive = true,
  });

  Future<void> updateUser(UserModel user);

  Future<void> changePassword(int userId, String newPassword);

  Future<void> deleteUser(int userId);
}

class DatabaseUserRepository implements UserRepository {
  const DatabaseUserRepository();

  @override
  Future<List<UserModel>> loadUsers() async {
    final rows = await DatabaseService.rawQuery(
      'SELECT * FROM users ORDER BY created_at DESC',
      [],
    );
    return rows.map(UserModel.fromMap).toList();
  }

  @override
  Future<bool> emailExists(String email) async {
    final rows = await DatabaseService.rawQuery(
      'SELECT id FROM users WHERE lower(email) = ?',
      [email.toLowerCase().trim()],
    );
    return rows.isNotEmpty;
  }

  @override
  Future<UserModel?> getUserById(int userId) async {
    final rows = await DatabaseService.rawQuery(
      'SELECT * FROM users WHERE id = ? LIMIT 1',
      [userId],
    );
    if (rows.isEmpty) return null;
    return UserModel.fromMap(rows.first);
  }

  @override
  Future<int> createUser({
    required String email,
    required String password,
    required String name,
    required String lastname,
    required String role,
    String? uid,
    bool isActive = true,
  }) async {
    final userId = await DatabaseService.rawInsert(
      '''INSERT INTO users (uid, email, password, name, lastname, role, is_active, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        uid ?? generateFirebaseId(),
        email.trim(),
        password,
        name.trim(),
        lastname.trim(),
        role,
        isActive ? 1 : 0,
        DateTime.now().toIso8601String(),
      ],
    );
    return userId;
  }

  @override
  Future<void> updateUser(UserModel user) async {
    await DatabaseService.rawUpdate(
      '''UPDATE users SET name = ?, lastname = ?, role = ?, is_active = ?
         WHERE id = ?''',
      [user.name, user.lastname, user.role, user.isActive ? 1 : 0, user.id],
    );
  }

  @override
  Future<void> changePassword(int userId, String newPassword) async {
    await DatabaseService.rawUpdate(
      'UPDATE users SET password = ? WHERE id = ?',
      [newPassword, userId],
    );
  }

  @override
  Future<void> deleteUser(int userId) async {
    await DatabaseService.rawDelete(
      'DELETE FROM users WHERE id = ?',
      [userId],
    );
  }
}
