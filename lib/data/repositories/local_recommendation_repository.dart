import '../../models/enums.dart';
import '../../models/recommendation_items.dart';
import '../datasources/local/recommendation_local_datasource.dart';
import 'recommendation_repository.dart';

class LocalRecommendationRepository implements RecommendationRepository {
  LocalRecommendationRepository(this._dataSource);

  final RecommendationLocalDataSource _dataSource;

  @override
  Future<List<RequirementItem>> getRequirements(
    int sportId,
    SportLevel level,
  ) =>
      _dataSource.getRequirements(sportId, level);

  @override
  Future<List<ExperienceItem>> getExperienceRecommendations(
    int sportId,
    int experienceYears,
  ) =>
      _dataSource.getExperienceRecommendations(sportId, experienceYears);
}
