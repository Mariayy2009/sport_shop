import 'package:shared_preferences/shared_preferences.dart';

/// Адрес сервера магазина, если пользователь его подключил.
abstract class ShopServerStorage {
  Future<String?> readUrl();

  Future<void> saveUrl(String? url);
}

class SharedPreferencesShopServerStorage implements ShopServerStorage {
  static const String _key = 'shop_server_url';

  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<String?> readUrl() => _preferences.getString(_key);

  @override
  Future<void> saveUrl(String? url) => url == null || url.isEmpty
      ? _preferences.remove(_key)
      : _preferences.setString(_key, url);
}

/// Хранение в памяти — для тестов.
class InMemoryShopServerStorage implements ShopServerStorage {
  String? url;

  @override
  Future<String?> readUrl() async => url;

  @override
  Future<void> saveUrl(String? value) async =>
      url = value == null || value.isEmpty ? null : value;
}
