import '../../models/enums.dart';
import '../../models/recommendation_items.dart';

/// Контракт получения данных для AI-подбора.
abstract class RecommendationRepository {
  Future<List<RequirementItem>> getRequirements(int sportId, SportLevel level);

  Future<List<ExperienceItem>> getExperienceRecommendations(
    int sportId,
    int experienceYears,
  );
}
