import '../models/product.dart';
import '../models/user_sizes.dart';

/// Насколько можно доверять совету по размеру.
enum SizeConfidence {
  /// Параметры профиля и расчёт по меркам совпали.
  high,

  /// Совет дан по части данных или размер пришлось заменить ближайшим.
  medium,
}

/// Совет по размеру для конкретного товара.
class SizeAdvice {
  const SizeAdvice({
    required this.size,
    required this.explanation,
    required this.confidence,
    this.alternative,
  });

  /// Рекомендуемый размер — всегда один из доступных у товара.
  final String size;

  /// Объяснение для пользователя: почему именно этот размер.
  final String explanation;
  final SizeConfidence confidence;

  /// Второй вариант, если мерки на границе размеров.
  final String? alternative;
}

/// Умный подбор размера: рост, вес и размеры из профиля + размерные таблицы.
///
/// Чистая логика без базы и UI — её же использует ИИ-помощник,
/// комплекты и карточка товара.
class SizeAdvisor {
  const SizeAdvisor();

  static const List<String> letterSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];

  /// Верхняя граница роста (см) для каждого буквенного размера.
  static const List<int> _heightLimits = [160, 165, 170, 176, 182];

  /// Верхняя граница веса (кг) для каждого буквенного размера.
  static const List<int> _weightLimits = [50, 58, 68, 78, 90];

  /// Буквенный размер одежды по росту и весу. null — данных нет.
  /// Берём больший из двух, чтобы вещь не была мала.
  String? clothingSizeByBody({int? height, int? weight}) {
    final int? byHeight = height == null ? null : _indexFor(height, _heightLimits);
    final int? byWeight = weight == null ? null : _indexFor(weight, _weightLimits);
    if (byHeight == null && byWeight == null) return null;
    final int index = [byHeight ?? 0, byWeight ?? 0]
        .reduce((a, b) => a > b ? a : b);
    return letterSizes[index];
  }

  /// Совет для товара. null — у товара нет размеров
  /// или в профиле нет данных, по которым можно выбрать.
  SizeAdvice? advise(Product product, UserSizes? sizes) {
    final List<String> available = product.availableSizes;
    if (available.isEmpty || sizes == null) return null;

    if (product.categoryName == 'Обувь') return _shoes(available, sizes);
    if (available.every(letterSizes.contains)) {
      return _letters(available, sizes);
    }
    if (available.every((size) => size.endsWith('oz'))) {
      return _gloves(available, sizes);
    }
    final List<int?> numbers = available.map(int.tryParse).toList();
    if (numbers.every((value) => value != null && value >= 100)) {
      return _byHeight(available, sizes);
    }
    return null;
  }

  /// Размер для автоматического добавления в корзину (комплекты, «Добавить всё»).
  String? pickSize(Product product, UserSizes? sizes) =>
      advise(product, sizes)?.size ??
      product.pickSize(
        clothingSize: sizes?.clothingSize,
        shoeSize: sizes?.shoeSize,
      );

  SizeAdvice? _letters(List<String> available, UserSizes sizes) {
    final String? fromProfile = sizes.clothingSize;
    final String? fromBody =
        clothingSizeByBody(height: sizes.height, weight: sizes.weight);
    final String? wanted = fromProfile ?? fromBody;
    if (wanted == null) return null;

    final String chosen = _nearestLetter(wanted, available);
    final bool replaced = chosen != wanted;
    final bool bodyDiffers =
        fromProfile != null && fromBody != null && fromBody != fromProfile;
    final String? alternative =
        bodyDiffers && available.contains(fromBody) && fromBody != chosen
            ? fromBody
            : null;

    final StringBuffer text = StringBuffer();
    if (fromProfile != null) {
      text.write('В профиле указан размер $fromProfile');
    } else {
      text.write('По росту ${sizes.height ?? '—'} см и весу '
          '${sizes.weight ?? '—'} кг подходит $fromBody');
    }
    if (replaced) {
      text.write(', но его нет у этого товара — ближайший $chosen');
    }
    if (alternative != null) {
      text.write('. По росту и весу ближе $alternative — '
          'выбирайте его для свободной посадки');
    }
    text.write('.');

    return SizeAdvice(
      size: chosen,
      explanation: text.toString(),
      confidence: !replaced && !bodyDiffers && fromProfile != null
          ? SizeConfidence.high
          : SizeConfidence.medium,
      alternative: alternative,
    );
  }

  SizeAdvice? _shoes(List<String> available, UserSizes sizes) {
    final int? shoeSize = sizes.shoeSize;
    if (shoeSize == null) return null;
    final String chosen = _nearestNumber(shoeSize, available);
    final bool exact = chosen == '$shoeSize';
    return SizeAdvice(
      size: chosen,
      explanation: exact
          ? 'Ваш размер обуви из профиля — $shoeSize. Для спортивной обуви '
              'оставляйте около 0,5 см запаса перед большим пальцем.'
          : 'Размера $shoeSize у этой модели нет — ближайший $chosen. '
              'Сверьте длину стопы с таблицей размеров.',
      confidence: exact ? SizeConfidence.high : SizeConfidence.medium,
    );
  }

  /// Боксёрские перчатки: вес перчатки в унциях зависит от веса спортсмена.
  SizeAdvice? _gloves(List<String> available, UserSizes sizes) {
    final int? weight = sizes.weight;
    if (weight == null) return null;
    final int ounces = weight < 55
        ? 10
        : weight < 70
            ? 12
            : weight < 85
                ? 14
                : 16;
    final String chosen = _nearestNumber(
      ounces,
      available,
      parse: (size) => int.tryParse(size.replaceAll('oz', '')),
    );
    return SizeAdvice(
      size: chosen,
      explanation: 'Для веса $weight кг на тренировках подходят перчатки '
          '$chosen: чем тяжелее спортсмен, тем больше защита кисти.',
      confidence: SizeConfidence.medium,
    );
  }

  /// Кимоно и другая одежда с ростовкой: 130, 140 ... 190.
  SizeAdvice? _byHeight(List<String> available, UserSizes sizes) {
    final int? height = sizes.height;
    if (height == null) return null;
    final List<int> values = available.map(int.parse).toList()..sort();
    // Ближайшая ростовка не меньше роста; если рост выше всех — самая большая.
    final int chosen =
        values.firstWhere((value) => value >= height - 2, orElse: () => values.last);
    return SizeAdvice(
      size: '$chosen',
      explanation: 'Ростовка подбирается по росту: при $height см '
          'берите $chosen, после стирки хлопок даёт небольшую усадку.',
      confidence: SizeConfidence.medium,
    );
  }

  static int _indexFor(int value, List<int> limits) {
    for (int i = 0; i < limits.length; i++) {
      if (value < limits[i]) return i;
    }
    return limits.length;
  }

  static String _nearestLetter(String wanted, List<String> available) {
    if (available.contains(wanted)) return wanted;
    final int target = letterSizes.indexOf(wanted);
    String best = available.first;
    int bestDistance = 1000;
    for (final String size in available) {
      final int index = letterSizes.indexOf(size);
      // При равном расстоянии выбираем больший размер.
      final int distance = (index - target).abs() * 2 - (index > target ? 1 : 0);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = size;
      }
    }
    return best;
  }

  static String _nearestNumber(
    int wanted,
    List<String> available, {
    int? Function(String size)? parse,
  }) {
    final int? Function(String) toNumber = parse ?? int.tryParse;
    String best = available.first;
    int bestDistance = 1 << 30;
    for (final String size in available) {
      final int? value = toNumber(size);
      if (value == null) continue;
      final int distance = (value - wanted).abs() * 2 - (value > wanted ? 1 : 0);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = size;
      }
    }
    return best;
  }
}
