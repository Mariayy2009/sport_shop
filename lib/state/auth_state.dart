import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

/// Состояние авторизации для экранов.
/// Экраны читают currentUser/role и вызывают login/register/logout.
/// Ошибки (AppException) пробрасываются экрану, чтобы показать сообщение.
class AuthState extends ChangeNotifier {
  AuthState(this._authService);

  final AuthService _authService;

  User? _currentUser;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  UserRole get role => _currentUser?.role ?? UserRole.guest;
  bool get isAdmin => role == UserRole.admin;

  Future<void> restoreSession() async {
    _currentUser = await _authService.restoreSession();
    notifyListeners();
  }

  Future<User> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    _setLoading(true);
    try {
      final User user = await _authService.login(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );
      _currentUser = user;
      return user;
    } finally {
      _setLoading(false);
    }
  }

  Future<User> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final User user = await _authService.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
      );
      _currentUser = user;
      return user;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    notifyListeners();
  }

  /// После редактирования профиля (этап 8).
  void updateCurrentUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
