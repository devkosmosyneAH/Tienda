import 'package:flutter_test/flutter_test.dart';
import 'package:tienda/Presentation/Controller/profile_controller.dart';
import 'package:tienda/Presentation/Services/auth_service.dart';

void main() {
  group('ProfilePermissions', () {
    test('admin_superior accede a todas las secciones administrativas', () {
      final permissions = ProfilePermissions.forRole('admin_superior');

      expect(permissions.canViewBusinessDetails, isTrue);
      expect(permissions.canManageUsers, isTrue);
      expect(permissions.canManageSystemSettings, isTrue);
      expect(permissions.canViewAudit, isTrue);
      expect(permissions.hasAdministration, isTrue);
      expect(
        ProfilePermissions.roleLabel('admin_superior'),
        'Administrador Superior',
      );
    });

    test('el rol legado admin conserva y comunica acceso superior', () {
      final permissions = ProfilePermissions.forRole('admin');

      expect(permissions.canManageUsers, isTrue);
      expect(permissions.canManageSystemSettings, isTrue);
      expect(permissions.canViewAudit, isTrue);
      expect(ProfilePermissions.roleLabel('admin'), 'Administrador Superior');
    });

    test('administrador ve negocio y configuración permitida, no usuarios', () {
      final permissions = ProfilePermissions.forRole('administrador');

      expect(permissions.canViewBusinessDetails, isTrue);
      expect(permissions.canManageUsers, isFalse);
      expect(permissions.canManageSystemSettings, isFalse);
      expect(permissions.canViewAudit, isFalse);
      expect(permissions.hasAdministration, isTrue);
    });

    test('cajero no obtiene secciones administrativas ni tributarias', () {
      final permissions = ProfilePermissions.forRole('cajero');

      expect(permissions.canViewBusinessDetails, isFalse);
      expect(permissions.canManageUsers, isFalse);
      expect(permissions.canManageSystemSettings, isFalse);
      expect(permissions.canViewAudit, isFalse);
      expect(permissions.hasAdministration, isFalse);
    });
  });

  test(
    'muestra la sesión real en solo lectura si la fila no se encuentra',
    () async {
      final controller = ProfileController(
        authService: _SessionOnlyAuthService(),
        activityLoader: (_) async => const [],
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.error, isNull);
      expect(controller.user?.uid, 'session-user-uid');
      expect(controller.user?.fullName, 'Anthony Cordova');
      expect(controller.user?.email, 'anthony@example.com');
      expect(controller.canEditProfile, isFalse);
    },
  );
}

class _SessionOnlyAuthService extends AuthService {
  static const _session = <String, dynamic>{
    'uid': 'session-user-uid',
    'email': 'anthony@example.com',
    'name': 'Anthony',
    'lastname': 'Cordova',
    'role': 'admin',
    'is_active': 1,
    'created_at': '2025-08-08T11:05:20.058581',
    'password': 'must-not-be-copied-into-profile-data',
  };

  @override
  Future<Map<String, dynamic>?> getCurrentUserRecord() async => null;

  @override
  Future<Map<String, dynamic>?> getCurrentUser() async => _session;
}
