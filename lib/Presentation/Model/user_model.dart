class UserModel {
  final int? id;
  final String uid;
  final String email;
  final String password;
  final String name;
  final String lastname;
  final String role;
  final bool isActive;
  final String createdAt;

  const UserModel({
    this.id,
    required this.uid,
    required this.email,
    required this.password,
    required this.name,
    required this.lastname,
    required this.role,
    this.isActive = true,
    required this.createdAt,
  });

  String get fullName => '$name $lastname'.trim();

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      uid: map['uid'] as String,
      email: map['email'] as String,
      password: map['password'] as String,
      name: map['name'] as String,
      lastname: (map['lastname'] as String?) ?? '',
      role: map['role'] as String,
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'uid': uid,
      'email': email,
      'password': password,
      'name': name,
      'lastname': lastname,
      'role': role,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
    };
  }

  UserModel copyWith({
    int? id,
    String? uid,
    String? email,
    String? password,
    String? name,
    String? lastname,
    String? role,
    bool? isActive,
    String? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      email: email ?? this.email,
      password: password ?? this.password,
      name: name ?? this.name,
      lastname: lastname ?? this.lastname,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Roles disponibles en el sistema
class UserRoles {
  static const String adminSuperior = 'admin_superior';
  static const String administrador = 'administrador';
  static const String cajero = 'cajero';

  static const List<String> all = [adminSuperior, administrador, cajero];

  static String label(String role) {
    switch (role) {
      case adminSuperior:
        return 'Admin Superior';
      case administrador:
        return 'Administrador';
      case cajero:
        return 'Cajero';
      // compatibilidad con registros antiguos
      case 'admin':
        return 'Administrador';
      default:
        return role;
    }
  }

  static String description(String role) {
    switch (role) {
      case adminSuperior:
        return 'Acceso total al sistema, gestión de usuarios';
      case administrador:
        return 'Gestión de ventas, inventario y reportes';
      case cajero:
        return 'Solo ventas y clientes';
      default:
        return '';
    }
  }
}
