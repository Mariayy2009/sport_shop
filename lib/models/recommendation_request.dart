import 'enums.dart';

/// Ответы опроса AI-подбора (экраны ии2–ии4).
/// Это вход RecommendationService — сейчас для локальной логики,
/// в дипломе тот же объект уйдёт в AI API через toJson().
class RecommendationRequest {
  const RecommendationRequest({
    required this.sportId,
    required this.level,
    required this.experienceYears,
    this.height,
    this.weight,
    this.clothingSize,
    this.shoeSize,
    this.budget,
  });

  final int sportId;
  final SportLevel level;
  final int experienceYears;
  final int? height;
  final int? weight;
  final String? clothingSize;
  final int? shoeSize;

  /// Максимальный бюджет в тенге (слайдер на экране ии4).
  final double? budget;

  Map<String, Object?> toJson() {
    return {
      'sport_id': sportId,
      'level': level.value,
      'experience_years': experienceYears,
      'height': height,
      'weight': weight,
      'clothing_size': clothingSize,
      'shoe_size': shoeSize,
      'budget': budget,
    };
  }
}
