import 'package:flutter/material.dart';
import 'package:tienda/Presentation/Services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _user;
  bool _loading = false;

  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get loading => _loading;

  Future<bool> signIn(String email, String password) async {
    _loading = true;
    notifyListeners();

    final user = await _authService.login(email, password);

    _loading = false;
    if (user != null) {
      _user = user;
      notifyListeners();
      return true;
    }

    notifyListeners();
    return false;
  }

  Future<void> signOut() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
  }

  Future<void> loadSession() async {
    final u = await _authService.getCurrentUser();
    _user = u;
    notifyListeners();
  }

  String? get role => _user?['role'];
}
