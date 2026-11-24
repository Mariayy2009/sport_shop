import '../../data/repositories/preferences_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../models/chat_message.dart';
import '../../models/product.dart';
import '../../models/shopping_preferences.dart';
import '../../models/sport.dart';
import '../../models/user.dart';
import '../../models/user_sizes.dart';
import 'assistant_engine.dart';

/// Точка входа для чата с ИИ-помощником:
/// собирает контекст (каталог, профиль) и передаёт его движку.
class AssistantService {
  AssistantService(this._engine, this._productRepository, this._preferences);

  final AssistantEngine _engine;
  final ProductRepository _productRepository;
  final PreferencesRepository _preferences;

  Future<AssistantReply> ask({
    required List<ChatMessage> history,
    User? user,
    UserSizes? sizes,
  }) async {
    final List<Product> catalog = await _productRepository.getProducts();
    final List<Sport> sports = await _productRepository.getSports();
    return _engine.reply(
      AssistantContext(
        catalog: catalog,
        sports: sports,
        user: user,
        sizes: sizes,
        // Анкета: любимые цвета, позиция, материалы — помощник учитывает
        // их в подборе.
        preferences: await _readPreferences(user?.id),
      ),
      history,
    );
  }

  /// Анкета не обязательна: если её не прочитать, помощник всё равно
  /// отвечает — просто без учёта вкусов.
  Future<ShoppingPreferences?> _readPreferences(int? userId) async {
    if (userId == null) return null;
    try {
      return await _preferences.read(userId);
    } on Object {
      return null;
    }
  }
}
