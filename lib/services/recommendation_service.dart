import '../data/repositories/recommendation_repository.dart';
import '../models/product.dart';
import '../models/recommendation_items.dart';
import '../models/recommendation_request.dart';
import '../models/recommended_product.dart';

/// «Движок» рекомендаций. UI не знает, какой движок используется:
/// сейчас LocalRecommendationEngine (правила из SQLite),
/// в дипломе — AiRecommendationEngine (запрос к AI API через сервер).
abstract class RecommendationEngine {
  Future<List<RecommendedProduct>> recommend(RecommendationRequest request);

  Future<List<RecommendedProduct>> whatElseToBuy({
    required int sportId,
    required int experienceYears,
    Set<int> excludeProductIds = const {},
  });
}

/// Локальная логика подбора на основе таблиц
/// sport_requirements, recommendations и products.
class LocalRecommendationEngine implements RecommendationEngine {
  LocalRecommendationEngine(this._repository);

  final RecommendationRepository _repository;

  @override
  Future<List<RecommendedProduct>> recommend(
    RecommendationRequest request,
  ) async {
    final List<RequirementItem> requirements =
        await _repository.getRequirements(request.sportId, request.level);

    final List<RecommendedProduct> result = [];
    final Set<int> addedIds = {};
    double total = 0;

    void add(Product product, String reason, bool isMandatory,
        RecommendationSource source) {
      result.add(RecommendedProduct(
        product: product,
        reason: reason,
        isMandatory: isMandatory,
        source: source,
      ));
      addedIds.add(product.id!);
      total += product.price;
    }

    // 1. Обязательные товары для уровня — всегда, даже сверх бюджета.
    for (final RequirementItem item in requirements) {
      if (!item.isMandatory) continue;
      add(item.product, _levelReason(item.product, request, mandatory: true),
          true, RecommendationSource.requirement);
    }

    // 2. Дополнительные для уровня — если есть в наличии и влезают в бюджет.
    for (final RequirementItem item in requirements) {
      if (item.isMandatory) continue;
      if (!_canAdd(item.product, total, request.budget, addedIds)) continue;
      add(item.product, _levelReason(item.product, request, mandatory: false),
          false, RecommendationSource.requirement);
    }

    // 3. «Что ещё купить?» по стажу.
    final List<ExperienceItem> extras = await _repository
        .getExperienceRecommendations(request.sportId, request.experienceYears);
    for (final ExperienceItem item in extras) {
      if (!_canAdd(item.product, total, request.budget, addedIds)) continue;
      add(item.product, item.reason, false, RecommendationSource.experience);
    }

    return result;
  }

  @override
  Future<List<RecommendedProduct>> whatElseToBuy({
    required int sportId,
    required int experienceYears,
    Set<int> excludeProductIds = const {},
  }) async {
    final List<ExperienceItem> extras =
        await _repository.getExperienceRecommendations(sportId, experienceYears);
    return extras
        .where((item) =>
            item.product.isAvailable &&
            !excludeProductIds.contains(item.product.id))
        .map((item) => RecommendedProduct(
              product: item.product,
              reason: item.reason,
              isMandatory: false,
              source: RecommendationSource.experience,
            ))
        .toList();
  }

  bool _canAdd(
    Product product,
    double currentTotal,
    double? budget,
    Set<int> addedIds,
  ) {
    if (addedIds.contains(product.id)) return false;
    if (!product.isAvailable) return false;
    if (budget != null && currentTotal + product.price > budget) return false;
    return true;
  }

  String _levelReason(
    Product product,
    RecommendationRequest request, {
    required bool mandatory,
  }) {
    final String base = mandatory
        ? 'Обязательно для уровня «${request.level.label}»'
        : 'Рекомендуется для уровня «${request.level.label}»';
    final String? size = _matchingSize(product, request);
    return size == null ? base : '$base · есть ваш размер $size';
  }

  String? _matchingSize(Product product, RecommendationRequest request) {
    final List<String> sizes = product.availableSizes;
    if (sizes.isEmpty) return null;
    final String? clothingSize = request.clothingSize;
    if (clothingSize != null && sizes.contains(clothingSize)) {
      return clothingSize;
    }
    final int? shoeSize = request.shoeSize;
    if (shoeSize != null && sizes.contains('$shoeSize')) return '$shoeSize';
    return null;
  }
}

/// Точка входа для экранов AI-подбора.
class RecommendationService {
  RecommendationService(this._engine);

  final RecommendationEngine _engine;

  Future<List<RecommendedProduct>> getRecommendations(
    RecommendationRequest request,
  ) =>
      _engine.recommend(request);

  Future<List<RecommendedProduct>> getWhatElseToBuy({
    required int sportId,
    required int experienceYears,
    Set<int> excludeProductIds = const {},
  }) =>
      _engine.whatElseToBuy(
        sportId: sportId,
        experienceYears: experienceYears,
        excludeProductIds: excludeProductIds,
      );

  static double totalPrice(List<RecommendedProduct> items) =>
      items.fold(0, (sum, item) => sum + item.product.price);
}
