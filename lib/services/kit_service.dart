import '../data/repositories/recommendation_repository.dart';
import '../models/enums.dart';
import '../models/recommendation_items.dart';
import '../models/sport.dart';
import '../models/sport_kit.dart';
import '../models/user_sizes.dart';
import 'size_advisor.dart';

/// Персональные комплекты: товары из sport_requirements
/// для вида спорта и уровня + размеры, подобранные под пользователя.
class KitService {
  KitService(this._repository, [this._sizeAdvisor = const SizeAdvisor()]);

  final RecommendationRepository _repository;
  final SizeAdvisor _sizeAdvisor;

  Future<SportKit> buildKit({
    required Sport sport,
    required SportLevel level,
    UserSizes? sizes,
  }) async {
    final List<RequirementItem> requirements =
        await _repository.getRequirements(sport.id!, level);
    return SportKit(
      sport: sport,
      level: level,
      items: [
        for (final RequirementItem item in requirements)
          KitItem(
            product: item.product,
            isMandatory: item.isMandatory,
            size: _sizeAdvisor.pickSize(item.product, sizes),
          ),
      ],
    );
  }
}
