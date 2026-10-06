/// Рекомендация по стажу (таблица recommendations) —
/// источник блока «Что ещё купить?».
class Recommendation {
  const Recommendation({
    this.id,
    required this.sportId,
    this.minExperience = 0,
    required this.productId,
    this.reason,
  });

  final int? id;
  final int sportId;

  /// Рекомендация показывается, если стаж >= этого значения (лет).
  final int minExperience;
  final int productId;
  final String? reason;

  bool isSuitableFor(int experienceYears) => experienceYears >= minExperience;

  factory Recommendation.fromMap(Map<String, Object?> map) {
    return Recommendation(
      id: map['id'] as int?,
      sportId: map['sport_id'] as int,
      minExperience: (map['min_experience'] as int?) ?? 0,
      productId: map['product_id'] as int,
      reason: map['reason'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'sport_id': sportId,
      'min_experience': minExperience,
      'product_id': productId,
      'reason': reason,
    };
  }

  factory Recommendation.fromJson(Map<String, Object?> json) =>
      Recommendation.fromMap(json);

  Map<String, Object?> toJson() => toMap();
}
