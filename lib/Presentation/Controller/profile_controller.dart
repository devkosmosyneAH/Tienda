import 'package:flutter/foundation.dart';
import 'package:tienda/Presentation/Model/audit_log_model.dart';
import 'package:tienda/Presentation/Model/user_model.dart';
import 'package:tienda/Presentation/Services/audit_service.dart';
import 'package:tienda/Presentation/Services/auth_service.dart';

typedef ProfileActivityLoader =
    Future<List<AuditLogModel>> Function(String uid);

class ProfilePermissions {
  const ProfilePermissions({
    required this.canViewBusinessDetails,
    required this.canManageUsers,
    required this.canManageSystemSettings,
    required this.canViewAudit,
  });

  final bool canViewBusinessDetails;
  final bool canManageUsers;
  final bool canManageSystemSettings;
  final bool canViewAudit;

  bool get hasAdministration =>
      canViewBusinessDetails ||
      canManageUsers ||
      canManageSystemSettings ||
      canViewAudit;

  factory ProfilePermissions.forRole(String role) {
    final isSuperior = role == 'admin_superior' || role == 'admin';
    return ProfilePermissions(
      canViewBusinessDetails: isSuperior || role == 'administrador',
      canManageUsers: isSuperior,
      canManageSystemSettings: isSuperior,
      canViewAudit: isSuperior,
    );
  }

  static String roleLabel(String role) => switch (role) {
    'admin_superior' || 'admin' => 'Administrador Superior',
    'administrador' => 'Administrador',
    'cajero' => 'Cajero',
    _ => UserRoles.label(role),
  };
}

class ProfileUserData {
  const ProfileUserData({
    required this.uid,
    required this.email,
    required this.name,
    required this.lastname,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  final String uid;
  final String email;
  final String name;
  final String lastname;
  final String role;
  final bool isActive;
  final String createdAt;

  String get fullName => '$name $lastname'.trim();

  factory ProfileUserData.fromUser(UserModel user) => ProfileUserData(
    uid: user.uid,
    email: user.email,
    name: user.name,
    lastname: user.lastname,
    role: user.role,
    isActive: user.isActive,
    createdAt: user.createdAt,
  );

  factory ProfileUserData.fromSession(Map<String, dynamic> session) =>
      ProfileUserData(
        uid: session['uid']?.toString() ?? '',
        email: session['email']?.toString() ?? '',
        name: session['name']?.toString() ?? '',
        lastname: session['lastname']?.toString() ?? '',
        role: session['role']?.toString() ?? '',
        isActive: switch (session['is_active']) {
          false => false,
          num value => value.toInt() != 0,
          _ => true,
        },
        createdAt: session['created_at']?.toString() ?? '',
      );
}

class ProfileController extends ChangeNotifier {
  ProfileController({
    AuthService? authService,
    ProfileActivityLoader? activityLoader,
  }) : _authService = authService ?? AuthService(),
       _activityLoader =
           activityLoader ??
           ((uid) => AuditService.query(userId: uid, limit: 5));

  final AuthService _authService;
  final ProfileActivityLoader _activityLoader;
  ProfileUserData? _user;
  List<AuditLogModel> _recentActivity = const [];
  bool _loading = false;
  bool _activityAvailable = false;
  bool _databaseRecordAvailable = false;
  String? _error;

  ProfileUserData? get user => _user;
  List<AuditLogModel> get recentActivity => _recentActivity;
  bool get loading => _loading;
  bool get activityAvailable => _activityAvailable;
  bool get canEditProfile => _databaseRecordAvailable;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final row = await _authService.getCurrentUserRecord();
      final session = row ?? await _authService.getCurrentUser();
      final uid = session?['uid']?.toString().trim() ?? '';
      if (session == null || uid.isEmpty) {
        _user = null;
        _databaseRecordAvailable = false;
        _error = 'No hay una sesión de usuario activa.';
        return;
      }
      _databaseRecordAvailable = row != null;
      _user = row == null
          ? ProfileUserData.fromSession(session)
          : ProfileUserData.fromUser(UserModel.fromMap(row));

      try {
        _recentActivity = await _activityLoader(uid);
        _activityAvailable = true;
      } catch (_) {
        _recentActivity = const [];
        _activityAvailable = false;
      }
    } catch (_) {
      _error = 'No se pudo cargar la información del perfil.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> updateProfile({
    required String name,
    required String lastname,
    required String email,
  }) async {
    if (!_databaseRecordAvailable) {
      return 'La cuenta no está disponible en la base de datos actual. Vuelve a iniciar sesión para editarla.';
    }
    final error = await _authService.updateCurrentUserProfile(
      name: name,
      lastname: lastname,
      email: email,
    );
    if (error == null) await load();
    return error;
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    if (!_databaseRecordAvailable) {
      return Future.value(
        'La cuenta no está disponible en la base de datos actual. Vuelve a iniciar sesión para cambiar la contraseña.',
      );
    }
    return _authService.changeCurrentUserPassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }
}
