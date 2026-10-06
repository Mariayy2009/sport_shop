import '../core/errors/app_exception.dart';
import '../core/utils/password_hasher.dart';
import '../data/datasources/local/session_local_datasource.dart';
import '../data/repositories/user_repository.dart';
import '../models/enums.dart';
import '../models/user.dart';

/// Вход, регистрация и выход.
///
/// Сейчас пароль проверяется локально по хешу из SQLite.
/// В дипломе этот сервис будет отправлять запрос на сервер
/// и хранить токен вместо id — экраны при этом не изменятся.
class AuthService {
  AuthService({
    required UserRepository userRepository,
    required SessionStorage sessionStorage,
  })  : _userRepository = userRepository,
        _sessionStorage = sessionStorage;

  final UserRepository _userRepository;
  final SessionStorage _sessionStorage;

  Future<User> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final User? user = await _userRepository.findByEmail(email.trim());
    if (user == null) {
      throw const AppException(
        'Пользователь с таким email не найден',
        field: 'email',
      );
    }
    if (!PasswordHasher.verify(password, user.passwordHash)) {
      throw const AppException('Неверный пароль', field: 'password');
    }

    if (rememberMe) {
      await _sessionStorage.saveUserId(user.id!);
    } else {
      await _sessionStorage.clear();
    }
    return user;
  }

  Future<User> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final User? existing = await _userRepository.findByEmail(normalizedEmail);
    if (existing != null) {
      throw const AppException(
        'Пользователь с таким email уже зарегистрирован',
        field: 'email',
      );
    }

    final User user = await _userRepository.create(
      User(
        email: normalizedEmail,
        passwordHash: PasswordHasher.hash(password),
        role: UserRole.customer,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        createdAt: DateTime.now(),
      ),
    );
    // После регистрации пользователь сразу входит в аккаунт.
    await _sessionStorage.saveUserId(user.id!);
    return user;
  }

  /// Пользователь из сохранённой сессии («Запомнить меня») или null.
  Future<User?> restoreSession() async {
    final int? userId = await _sessionStorage.readUserId();
    if (userId == null) return null;

    final User? user = await _userRepository.findById(userId);
    if (user == null) await _sessionStorage.clear();
    return user;
  }

  Future<void> logout() => _sessionStorage.clear();
}
