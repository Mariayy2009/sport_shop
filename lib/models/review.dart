/// Отзыв покупателя о товаре (таблица reviews).
/// Один пользователь — один отзыв на товар; повторный заменяет прежний.
class Review {
  const Review({
    this.id,
    required this.userId,
    required this.productId,
    required this.rating,
    this.text,
    required this.createdAt,
    this.authorName,
    this.authorAvatarPath,
    this.photos = const [],
  });

  static const int minRating = 1;
  static const int maxRating = 5;
  static const int maxTextLength = 500;

  final int? id;
  final int userId;
  final int productId;

  /// Оценка от 1 до 5.
  final int rating;
  final String? text;
  final DateTime createdAt;

  /// Фото покупателя к отзыву (пути к файлам).
  final List<String> photos;

  // Заполняются через JOIN с users.
  final String? authorName;
  final String? authorAvatarPath;

  factory Review.fromMap(Map<String, Object?> map) {
    return Review(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      productId: map['product_id'] as int,
      rating: map['rating'] as int,
      text: map['text'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      photos: [
        for (final String line in ((map['photos'] as String?) ?? '').split('\n'))
          if (line.trim().isNotEmpty) line.trim(),
      ],
      authorName: map['author_name'] as String?,
      authorAvatarPath: map['author_avatar_path'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'product_id': productId,
      'rating': rating,
      'text': text,
      'photos': photos.isEmpty ? null : photos.join('\n'),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
