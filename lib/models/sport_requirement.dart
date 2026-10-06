import 'enums.dart';

/// Требование к экипировке (таблица sport_requirements):
/// какой товар нужен для вида спорта и уровня подготовки.
class SportRequirement {
  const SportRequirement({
    this.id,
    required this.sportId,
    required this.productId,
    required this.level,
    required this.isMandatory,
  });

  final int? id;
  final int sportId;
  final int productId;
  final SportLevel level;

  /// true — блок «Обязательные», false — «Дополнительные».
  final bool isMandatory;

  factory SportRequirement.fromMap(Map<String, Object?> map) {
    return SportRequirement(
      id: map['id'] as int?,
      sportId: map['sport_id'] as int,
      productId: map['product_id'] as int,
      level: SportLevel.fromValue(map['level'] as String?),
      // В SQLite нет BOOLEAN: храним 1/0.
      isMandatory: (map['is_mandatory'] as int?) == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'sport_id': sportId,
      'product_id': productId,
      'level': level.value,
      'is_mandatory': isMandatory ? 1 : 0,
    };
  }

  factory SportRequirement.fromJson(Map<String, Object?> json) =>
      SportRequirement.fromMap(json);

  Map<String, Object?> toJson() => toMap();
}
