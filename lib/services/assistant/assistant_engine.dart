import '../../models/chat_message.dart';
import '../../models/product.dart';
import '../../models/shopping_preferences.dart';
import '../../models/sport.dart';
import '../../models/user.dart';
import '../../models/user_sizes.dart';

/// Всё, что помощник знает о покупателе и магазине в момент вопроса.
class AssistantContext {
  const AssistantContext({
    required this.catalog,
    required this.sports,
    this.user,
    this.sizes,
    this.preferences,
  });

  /// Реальный каталог: помощник советует только товары отсюда.
  final List<Product> catalog;
  final List<Sport> sports;
  final User? user;
  final UserSizes? sizes;

  /// Анкета покупателя (цвета, позиция, материалы).
  final ShoppingPreferences? preferences;

  Sport? sportById(int? id) {
    for (final Sport sport in sports) {
      if (sport.id == id) return sport;
    }
    return null;
  }

  Product? productById(int? id) {
    for (final Product product in catalog) {
      if (product.id == id) return product;
    }
    return null;
  }
}

/// «Мозг» помощника. UI и состояние не знают, какой движок работает:
///   LocalAssistantEngine  — правила поверх каталога, работает офлайн;
///   ClaudeAssistantEngine — языковая модель (через API или свой сервер).
abstract class AssistantEngine {
  /// [history] — весь диалог, последним идёт новое сообщение пользователя.
  Future<AssistantReply> reply(
    AssistantContext context,
    List<ChatMessage> history,
  );
}
