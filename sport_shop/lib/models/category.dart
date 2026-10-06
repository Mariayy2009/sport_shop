/// Категория товара (таблица categories).
///
/// Класс назван ProductCategory, а не Category: в Flutter уже есть
/// аннотация Category (package:flutter/foundation.dart), и одинаковые
/// имена вызвали бы ошибку «ambiguous import» в экранах.
class ProductCategory {
  const ProductCategory({
    this.id,
    required this.name,
    this.sportId,
  });

  final int? id;
  final String name;

  /// null — категория общая для всех видов спорта.
  final int? sportId;

  factory ProductCategory.fromMap(Map<String, Object?> map) {
    return ProductCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      sportId: map['sport_id'] as int?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'sport_id': sportId,
    };
  }

  factory ProductCategory.fromJson(Map<String, Object?> json) =>
      ProductCategory.fromMap(json);

  Map<String, Object?> toJson() => toMap();

  @override
  bool operator ==(Object other) =>
      other is ProductCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
