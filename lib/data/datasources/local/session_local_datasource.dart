import 'package:shared_preferences/shared_preferences.dart';

/// Хранение сессии для «Запомнить меня»: id вошедшего пользователя.
abstract class SessionStorage {
  Future<int?> readUserId();

  Future<void> saveUserId(int userId);

  Future<void> clear();
}

/// Сессия в памяти устройства (сохраняется между запусками).
class SharedPreferencesSessionStorage implements SessionStorage {
  static const String _userIdKey = 'session_user_id';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<int?> readUserId() => _preferences.getInt(_userIdKey);

  @override
  Future<void> saveUserId(int userId) => _preferences.setInt(_userIdKey, userId);

  @override
  Future<void> clear() => _preferences.remove(_userIdKey);
}

/// Сессия только в оперативной памяти — для тестов.
class InMemorySessionStorage implements SessionStorage {
  int? _userId;

  @override
  Future<int?> readUserId() async => _userId;

  @override
  Future<void> saveUserId(int userId) async => _userId = userId;

  @override
  Future<void> clear() async => _userId = null;
}
