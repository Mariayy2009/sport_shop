import 'package:shared_preferences/shared_preferences.dart';

/// Хранение ключа языковой модели, который пользователь ввёл в приложении.
abstract class AiKeyStore {
  Future<String?> readGeminiKey();

  Future<void> saveGeminiKey(String? key);
}

/// Ключ в настройках приложения на устройстве.
///
/// Для учебного проекта этого достаточно. В боевой версии ключ хранится
/// на сервере, а приложение обращается к серверу — иначе ключ можно
/// извлечь из памяти устройства.
class SharedPreferencesAiKeyStore implements AiKeyStore {
  static const String _geminiKey = 'ai_gemini_key';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<String?> readGeminiKey() => _preferences.getString(_geminiKey);

  @override
  Future<void> saveGeminiKey(String? key) => key == null || key.isEmpty
      ? _preferences.remove(_geminiKey)
      : _preferences.setString(_geminiKey, key);
}

/// Ключ только в оперативной памяти — для тестов.
class InMemoryAiKeyStore implements AiKeyStore {
  InMemoryAiKeyStore([this._key]);

  String? _key;

  @override
  Future<String?> readGeminiKey() async => _key;

  @override
  Future<void> saveGeminiKey(String? key) async =>
      _key = key == null || key.isEmpty ? null : key;
}
