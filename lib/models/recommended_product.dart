import 'product.dart';

/// Откуда взялась рекомендация.
enum RecommendationSource {
  /// Из sport_requirements (вид спорта + уровень).
  requirement,

  /// Из recommendations (стаж) — блок «Что ещё купить?».
  experience,

  /// Будущий источник — внешний AI API.
  ai,
}

/// Результат AI-подбора: товар + причина.
/// UI показывает его одинаково, откуда бы ни пришла рекомендация.
class RecommendedProduct {
  const RecommendedProduct({
    required this.product,
    required this.reason,
    required this.isMandatory,
    required this.source,
  });

  final Product product;
  final String reason;
  final bool isMandatory;
  final RecommendationSource source;
}
