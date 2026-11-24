import 'package:shared_preferences/shared_preferences.dart';

import '../../models/shopping_preferences.dart';

/// Где хранится анкета покупателя. Сейчас — на телефоне; при переходе
/// на сервер (шаг 2 PostgreSQL) появится реализация через API.
abstract class PreferencesRepository {
  Future<ShoppingPreferences> read(int userId);

  Future<void> save(int userId, ShoppingPreferences preferences);
}

class LocalPreferencesRepository implements PreferencesRepository {
  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  static String _key(int userId) => 'shopping_preferences_$userId';

  @override
  Future<ShoppingPreferences> read(int userId) async =>
      ShoppingPreferences.decode(await _preferences.getString(_key(userId)));

  @override
  Future<void> save(int userId, ShoppingPreferences preferences) =>
      _preferences.setString(_key(userId), preferences.encode());
}

/// Для тестов.
class InMemoryPreferencesRepository implements PreferencesRepository {
  final Map<int, ShoppingPreferences> _saved = {};

  @override
  Future<ShoppingPreferences> read(int userId) async =>
      _saved[userId] ?? const ShoppingPreferences();

  @override
  Future<void> save(int userId, ShoppingPreferences preferences) async =>
      _saved[userId] = preferences;
}
