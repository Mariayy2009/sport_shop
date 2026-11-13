/// Вопрос покупателя о товаре (таблица questions).
/// Задать может любой вошедший пользователь, отвечает администратор.
class Question {
  const Question({
    this.id,
    required this.productId,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.answer,
    this.answeredAt,
    this.authorName,
    this.productName,
  });

  static const int maxTextLength = 300;

  final int? id;
  final int productId;
  final int userId;
  final String text;
  final DateTime createdAt;

  /// Ответ магазина (null — пока без ответа).
  final String? answer;
  final DateTime? answeredAt;

  // Заполняются через JOIN.
  final String? authorName;
  final String? productName;

  bool get isAnswered => answer != null && answer!.trim().isNotEmpty;

  factory Question.fromMap(Map<String, Object?> map) {
    final String? answeredAt = map['answered_at'] as String?;
    return Question(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      userId: map['user_id'] as int,
      text: map['text'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      answer: map['answer'] as String?,
      answeredAt: answeredAt == null ? null : DateTime.parse(answeredAt),
      authorName: map['author_name'] as String?,
      productName: map['product_name'] as String?,
    );
  }
}
