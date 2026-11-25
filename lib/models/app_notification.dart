/// Уведомление в приложении: «Продавец ответил», «Заказ в пути»,
/// продавцу — «Товар заканчивается».
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    this.body,
    this.productId,
    this.orderId,
    required this.createdAt,
    required this.isRead,
  });

  final int id;
  final String title;
  final String? body;

  /// Куда ведёт нажатие: карточка товара или заказ.
  final int? productId;
  final int? orderId;
  final DateTime createdAt;
  final bool isRead;

  factory AppNotification.fromMap(Map<String, Object?> map) => AppNotification(
        id: map['id']! as int,
        title: map['title']! as String,
        body: map['body'] as String?,
        productId: map['product_id'] as int?,
        orderId: map['order_id'] as int?,
        createdAt: DateTime.parse(map['created_at']! as String),
        isRead: (map['is_read'] as int? ?? 0) == 1,
      );
}
