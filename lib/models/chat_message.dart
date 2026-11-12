import 'product.dart';

enum ChatRole { user, assistant }

/// Товар, который помощник предлагает в ответе, с объяснением выбора.
class ProductPick {
  const ProductPick({required this.product, required this.reason, this.size});

  final Product product;

  /// Почему помощник советует именно этот товар.
  final String reason;

  /// Размер, подобранный под пользователя (если известен).
  final String? size;
}

/// Ответ помощника: текст + товары из каталога + подсказки-продолжения.
class AssistantReply {
  const AssistantReply({
    required this.text,
    this.picks = const [],
    this.suggestions = const [],
    this.isKit = false,
  });

  final String text;
  final List<ProductPick> picks;

  /// Быстрые варианты следующего вопроса (чипы под сообщением).
  final List<String> suggestions;

  /// Товары образуют комплект — UI предлагает добавить всё сразу.
  final bool isKit;
}

/// Сообщение в чате с помощником.
class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    this.picks = const [],
    this.suggestions = const [],
    this.isKit = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ChatMessage.user(String text) =>
      ChatMessage(role: ChatRole.user, text: text);

  factory ChatMessage.fromReply(AssistantReply reply) => ChatMessage(
        role: ChatRole.assistant,
        text: reply.text,
        picks: reply.picks,
        suggestions: reply.suggestions,
        isKit: reply.isKit,
      );

  final ChatRole role;
  final String text;
  final List<ProductPick> picks;
  final List<String> suggestions;
  final bool isKit;
  final DateTime createdAt;

  bool get isUser => role == ChatRole.user;

  double get picksTotal =>
      picks.fold(0, (sum, pick) => sum + pick.product.price);
}
