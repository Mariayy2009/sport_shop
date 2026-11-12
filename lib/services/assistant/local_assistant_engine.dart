import '../../core/utils/formatters.dart';
import '../../data/repositories/recommendation_repository.dart';
import '../../models/chat_message.dart';
import '../../models/enums.dart';
import '../../models/product.dart';
import '../../models/recommendation_items.dart';
import '../../models/sport.dart';
import '../size_advisor.dart';
import 'assistant_engine.dart';

/// Помощник без сети: понимает намерение по ключевым словам и отвечает
/// только данными из каталога, требований к экипировке и профиля.
///
/// Работает офлайн и служит запасным вариантом, если языковая модель
/// недоступна. Умеет: собрать комплект, найти товары под бюджет,
/// сравнить товары, подсказать размер.
class LocalAssistantEngine implements AssistantEngine {
  LocalAssistantEngine(
    this._recommendations, [
    this._sizeAdvisor = const SizeAdvisor(),
  ]);

  final RecommendationRepository _recommendations;
  final SizeAdvisor _sizeAdvisor;

  static const int _maxPicks = 4;

  /// Основы слов → название вида спорта из таблицы sports.
  static const Map<String, String> _sportStems = {
    'волейбол': 'Волейбол',
    'футбол': 'Футбол',
    'баскетбол': 'Баскетбол',
    'плаван': 'Плавание',
    'бассейн': 'Плавание',
    'бокс': 'Бокс',
    'карат': 'Карате',
    'йог': 'Йога',
    'фитнес': 'Фитнес',
    'тренажер': 'Фитнес',
    'качалк': 'Фитнес',
    'пробеж': 'Бег',
    'марафон': 'Бег',
    'бегов': 'Бег',
    'бегат': 'Бег',
  };

  /// Основы слов → название категории из таблицы categories.
  static const Map<String, String> _categoryStems = {
    'кроссовк': 'Обувь',
    'обув': 'Обувь',
    'бутс': 'Обувь',
    'одежд': 'Одежда',
    'форм': 'Одежда',
    'футболк': 'Одежда',
    'шорт': 'Одежда',
    'штан': 'Одежда',
    'леггинс': 'Одежда',
    'тайтс': 'Одежда',
    'кимоно': 'Одежда',
    'купальник': 'Одежда',
    'защит': 'Защита',
    'наколенник': 'Защита',
    'щитк': 'Защита',
    'фиксатор': 'Защита',
    'мяч': 'Инвентарь',
    'гир': 'Инвентарь',
    'гантел': 'Инвентарь',
    'инвентар': 'Инвентарь',
    'аксессуар': 'Аксессуары',
    'рюкзак': 'Аксессуары',
    'часы': 'Аксессуары',
    'бутылк': 'Аксессуары',
    'коврик': 'Аксессуары',
  };

  @override
  Future<AssistantReply> reply(
    AssistantContext context,
    List<ChatMessage> history,
  ) async {
    final String text = _normalize(history.last.text);
    final _Query query = _parse(text, context, history);

    if (_hasAny(text, const ['сравни', 'сравнен', 'что лучше', 'чем отлича'])) {
      return _compare(context, query);
    }
    if (_hasAny(text, const ['размер', 'мал ', 'велик', 'ростовк'])) {
      return _size(context, query);
    }
    if (_hasAny(text, const [
      'комплект',
      'набор',
      'собери',
      'собрать',
      'экипировк',
      'что нужно',
      'что купить',
      'с чего начать',
      'подбери все',
    ])) {
      return _kit(context, query);
    }
    if (query.hasProductSignal) return _search(context, query);
    if (_hasAny(text, const ['привет', 'здравств', 'добрый', 'умеешь', 'помощ', 'помоги'])) {
      return _intro(context);
    }
    if (query.sport != null) return _kit(context, query);
    return _clarify(context);
  }

  // ---------------------------------------------------------------------------
  // Разбор запроса
  // ---------------------------------------------------------------------------

  _Query _parse(String text, AssistantContext context, List<ChatMessage> history) {
    Sport? sport = _findSport(text, context);
    final bool sportMentioned = sport != null;
    // Вид спорта мог быть назван раньше в диалоге — помним контекст.
    if (sport == null) {
      for (final ChatMessage message in history.reversed.skip(1)) {
        if (!message.isUser) continue;
        sport = _findSport(_normalize(message.text), context);
        if (sport != null) break;
      }
    }
    sport ??= context.sportById(context.sizes?.sportId);

    String? category;
    for (final MapEntry<String, String> entry in _categoryStems.entries) {
      if (text.contains(entry.key)) {
        category = entry.value;
        break;
      }
    }

    SportLevel? level;
    if (_hasAny(text, const ['нович', 'начина', 'первый раз', 'впервые'])) {
      level = SportLevel.beginner;
    } else if (text.contains('любител')) {
      level = SportLevel.amateur;
    } else if (_hasAny(text, const ['опытн', 'профи', 'профессионал', 'давно'])) {
      level = SportLevel.experienced;
    }
    level ??= SportLevel.fromExperience(context.sizes?.experienceYears ?? 0);

    return _Query(
      text: text,
      sport: sport,
      sportMentioned: sportMentioned,
      category: category,
      level: level,
      budget: _findBudget(text),
      wantsCheap: _hasAny(text, const ['дешев', 'недорог', 'бюджетн', 'эконом']),
      named: _productsNamedIn(text, context.catalog),
    );
  }

  Sport? _findSport(String text, AssistantContext context) {
    String? name;
    for (final MapEntry<String, String> entry in _sportStems.entries) {
      if (text.contains(entry.key)) {
        name = entry.value;
        break;
      }
    }
    // «бег», «бега», «бегу» — отдельным словом, чтобы не ловить «бегемот».
    if (name == null && RegExp(r'(^|[^а-я])бег(а|у|ом|е)?([^а-я]|$)').hasMatch(text)) {
      name = 'Бег';
    }
    if (name == null && RegExp(r'(^|[^а-я])зал(а|е|ом)?([^а-я]|$)').hasMatch(text)) {
      name = 'Фитнес';
    }
    if (name == null) return null;
    for (final Sport sport in context.sports) {
      if (sport.name == name) return sport;
    }
    return null;
  }

  /// «до 50 000», «бюджет 30 тыс», «не дороже 20к», «15000 тенге».
  static double? _findBudget(String text) {
    final RegExpMatch? match = RegExp(
          r'(?:до|бюджет[а-я]*|не дороже|дешевле|в пределах|за)\s*(\d[\d\s]{0,8})\s*(тыс|к(?![а-я]))?',
        ).firstMatch(text) ??
        RegExp(r'(\d[\d\s]{2,8})\s*(тыс|к(?![а-я]))?\s*(?:₸|тг|тенге)')
            .firstMatch(text);
    if (match == null) return null;
    final double? value =
        double.tryParse(match.group(1)!.replaceAll(RegExp(r'\s'), ''));
    if (value == null || value <= 0) return null;
    // «до 50» и «до 50 тыс» — это тысячи тенге.
    return match.group(2) != null || value < 1000 ? value * 1000 : value;
  }

  /// Товары, названия которых узнаются в тексте запроса.
  static List<Product> _productsNamedIn(String text, List<Product> catalog) {
    final Map<Product, int> scores = {};
    int best = 0;
    for (final Product product in catalog) {
      int score = 0;
      for (final String word in _normalize(product.name).split(RegExp(r'[^а-яa-z0-9]+'))) {
        if (word.length < 4) continue;
        final String stem = word.substring(0, word.length < 6 ? word.length - 1 : 5);
        if (text.contains(stem)) score++;
      }
      if (score == 0) continue;
      scores[product] = score;
      if (score > best) best = score;
    }
    return [
      for (final MapEntry<Product, int> entry in scores.entries)
        if (entry.value == best) entry.key,
    ];
  }

  // ---------------------------------------------------------------------------
  // Ответы
  // ---------------------------------------------------------------------------

  AssistantReply _intro(AssistantContext context) {
    final String name = context.user?.greetingName ?? 'друг';
    final Sport? sport = context.sportById(context.sizes?.sportId);
    return AssistantReply(
      text: 'Привет, $name! Я помогу выбрать экипировку: соберу комплект под '
          'вид спорта и уровень, подберу размер, сравню товары и уложусь '
          'в бюджет. Советую только то, что есть в каталоге.'
          '${sport == null ? '\n\nКаким спортом занимаешься?' : ''}',
      suggestions: sport == null
          ? [for (final Sport item in context.sports.take(4)) item.name]
          : _followUps(sport),
    );
  }

  AssistantReply _clarify(AssistantContext context) {
    return AssistantReply(
      text: 'Подскажи вид спорта — и я соберу комплект, подберу размер '
          'или найду товар под бюджет. Например: «Собери комплект для '
          'волейбола до 30 000 ₸».',
      suggestions: [for (final Sport item in context.sports.take(5)) item.name],
    );
  }

  Future<AssistantReply> _kit(AssistantContext context, _Query query) async {
    final Sport? sport = query.sport;
    if (sport == null) return _clarify(context);

    final List<RequirementItem> requirements =
        await _recommendations.getRequirements(sport.id!, query.level);
    if (requirements.isEmpty) {
      return AssistantReply(
        text: 'Для вида спорта «${sport.name}» готового комплекта пока нет. '
            'Посмотри товары в каталоге.',
      );
    }

    final double? budget = query.budget;
    final List<ProductPick> picks = [];
    final List<String> skipped = [];
    double total = 0;
    for (final RequirementItem item in requirements) {
      final Product product = item.product;
      if (!product.isAvailable) {
        skipped.add('${product.name} — нет в наличии');
        continue;
      }
      // Основа комплекта входит всегда, дополнения — пока хватает бюджета.
      if (!item.isMandatory && budget != null && total + product.price > budget) {
        skipped.add('${product.name} — не вошло в бюджет');
        continue;
      }
      total += product.price;
      picks.add(_pick(
        context,
        product,
        lead: item.isMandatory
            ? 'Основа комплекта для уровня «${query.level.label}»'
            : 'Полезное дополнение',
      ));
    }

    final StringBuffer text = StringBuffer()
      ..write('Комплект для ${_genitive(sport)} · уровень '
          '«${query.level.label.toLowerCase()}». '
          '${Formatters.itemsCount(picks.length)} на '
          '${Formatters.price(total)}.');
    if (budget != null) {
      text.write(total <= budget
          ? ' В бюджет ${Formatters.price(budget)} укладываемся, '
              'остаётся ${Formatters.price(budget - total)}.'
          : ' Это на ${Formatters.price(total - budget)} больше бюджета: '
              'основу комплекта сокращать не стоит, но можно начать '
              'с самого важного — обуви и защиты.');
    }
    if (context.sizes == null || !context.sizes!.isComplete) {
      text.write('\n\nЗаполни рост, вес и размеры в профиле — подберу '
          'размеры автоматически.');
    }
    if (skipped.isNotEmpty) {
      text.write('\n\nНе добавлено: ${skipped.join('; ')}.');
    }

    return AssistantReply(
      text: text.toString(),
      picks: picks,
      isKit: true,
      suggestions: [
        if (budget == null) 'Уложись в ${Formatters.price(_roundBudget(total * 0.7))}',
        'Какой размер мне подойдёт?',
        'Сравни обувь',
      ],
    );
  }

  AssistantReply _search(AssistantContext context, _Query query) {
    List<Product> found;
    if (query.named.isNotEmpty && query.named.length <= 6) {
      found = query.named;
      // «кроссовки для волейбола» — оставляем товары названного вида спорта.
      if (query.sportMentioned) {
        final List<Product> ofSport = found
            .where((product) => product.sportId == query.sport!.id)
            .toList();
        if (ofSport.isNotEmpty) found = ofSport;
      }
    } else {
      found = context.catalog
          .where((product) =>
              (query.category == null || product.categoryName == query.category) &&
              (query.sport == null || product.sportId == query.sport!.id))
          .toList();
    }

    final double? budget = query.budget;
    final List<Product> affordable = budget == null
        ? found
        : found.where((product) => product.price <= budget).toList();
    final List<Product> available =
        affordable.where((product) => product.isAvailable).toList();

    if (available.isEmpty) {
      final List<Product> cheapest = List.of(found)
        ..sort((a, b) => a.price.compareTo(b.price));
      if (cheapest.isEmpty) return _clarify(context);
      return AssistantReply(
        text: 'В бюджет ${Formatters.price(budget ?? 0)} ничего подходящего '
            'не нашлось. Самый доступный вариант — «${cheapest.first.name}» '
            'за ${Formatters.price(cheapest.first.price)}.',
        picks: [_pick(context, cheapest.first, lead: 'Самый доступный вариант')],
      );
    }

    available.sort(query.wantsCheap
        ? (a, b) => a.price.compareTo(b.price)
        : (a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    final List<Product> top = available.take(_maxPicks).toList();

    final String scope = [
      if (query.category != null) query.category!.toLowerCase(),
      if (query.sport != null) 'для ${_genitive(query.sport!)}',
      if (budget != null) 'до ${Formatters.price(budget)}',
    ].join(' ');
    return AssistantReply(
      text: 'Нашёл ${Formatters.itemsCount(available.length)}'
          '${scope.isEmpty ? '' : ' ($scope)'}. '
          '${query.wantsCheap ? 'Сначала самые доступные' : 'Сначала с лучшим рейтингом'}:',
      picks: [
        for (int i = 0; i < top.length; i++)
          _pick(
            context,
            top[i],
            lead: i == 0
                ? (query.wantsCheap ? 'Самая низкая цена' : 'Лучший рейтинг в подборке')
                : null,
          ),
      ],
      suggestions: [
        if (top.length > 1) 'Сравни их',
        if (query.sport != null) 'Собери комплект для ${_genitive(query.sport!)}',
        if (!query.wantsCheap) 'Покажи подешевле',
      ],
    );
  }

  AssistantReply _compare(AssistantContext context, _Query query) {
    List<Product> items = query.named.length >= 2 ? query.named : const [];
    if (items.length < 2) {
      // Нечего сравнивать по названию — берём категорию в виде спорта.
      final String category = query.category ?? 'Обувь';
      items = context.catalog
          .where((product) =>
              product.categoryName == category &&
              (!query.sportMentioned || product.sportId == query.sport!.id))
          .toList();
      if (items.length < 2 && query.sport != null) {
        items = context.catalog
            .where((product) => product.sportId == query.sport!.id)
            .toList();
      }
    }
    if (items.length < 2) {
      return const AssistantReply(
        text: 'Назови два товара или категорию, например: '
            '«Сравни кроссовки для бега и кроссовки для зала».',
      );
    }
    items = (List.of(items)
          ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0)))
        .take(3)
        .toList();

    final Product cheapest =
        items.reduce((a, b) => a.price <= b.price ? a : b);
    final Product bestRated =
        items.reduce((a, b) => (a.rating ?? 0) >= (b.rating ?? 0) ? a : b);

    final StringBuffer text = StringBuffer('Сравнил ${items.length} товара:\n');
    for (final Product product in items) {
      text.write('\n• ${product.name} — ${Formatters.price(product.price)}, '
          '${product.brand ?? 'бренд не указан'}, '
          'рейтинг ${_rating(product)}, '
          '${product.material ?? 'материал не указан'}');
    }
    text.write('\n\n');
    if (cheapest == bestRated) {
      text.write('«${cheapest.name}» выигрывает и по цене, и по рейтингу — '
          'беру его в рекомендацию.');
    } else {
      text.write('Дешевле всего «${cheapest.name}», выше всех оценён '
          '«${bestRated.name}». Если тренируешься регулярно, разница '
          '${Formatters.price(bestRated.price - cheapest.price)} окупится '
          'комфортом; для первых занятий хватит варианта подешевле.');
    }

    return AssistantReply(
      text: text.toString(),
      picks: [
        for (final Product product in items)
          _pick(
            context,
            product,
            lead: product == bestRated
                ? 'Выше всех оценён покупателями'
                : product == cheapest
                    ? 'Самая низкая цена'
                    : null,
          ),
      ],
      suggestions: const ['Какой размер мне подойдёт?'],
    );
  }

  AssistantReply _size(AssistantContext context, _Query query) {
    if (context.sizes == null) {
      return const AssistantReply(
        text: 'Чтобы подсказать размер, мне нужны рост, вес, размер одежды '
            'и обуви. Заполни их в профиле — и я подберу размер для любого '
            'товара.',
      );
    }
    final List<Product> candidates = (query.named.isNotEmpty && query.named.length <= 6
            ? query.named
            : context.catalog.where((product) =>
                query.sport == null || product.sportId == query.sport!.id))
        .where((product) =>
            product.requiresSize &&
            (query.category == null || product.categoryName == query.category))
        .toList();

    final List<ProductPick> picks = [];
    for (final Product product in candidates) {
      final SizeAdvice? advice = _sizeAdvisor.advise(product, context.sizes);
      if (advice == null) continue;
      picks.add(ProductPick(
        product: product,
        reason: 'Размер ${advice.size}. ${advice.explanation}',
        size: advice.size,
      ));
      if (picks.length == _maxPicks) break;
    }
    if (picks.isEmpty) {
      return const AssistantReply(
        text: 'Для этих товаров размер подбирать не нужно или в профиле '
            'не хватает параметров. Уточни товар — например, «какой размер '
            'кроссовок для волейбола мне нужен?»',
      );
    }
    final String? byBody = _sizeAdvisor.clothingSizeByBody(
      height: context.sizes!.height,
      weight: context.sizes!.weight,
    );
    return AssistantReply(
      text: 'Подобрал размеры по твоим параметрам'
          '${byBody == null ? '' : ' (по росту и весу одежда — $byBody)'}. '
          'Если мерки на границе размеров, для игровых видов спорта лучше '
          'брать больший.',
      picks: picks,
      suggestions: [
        if (query.sport != null) 'Собери комплект для ${_genitive(query.sport!)}',
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Вспомогательное
  // ---------------------------------------------------------------------------

  /// Объяснение выбора: роль товара + факты из каталога + размер.
  ProductPick _pick(AssistantContext context, Product product, {String? lead}) {
    final SizeAdvice? advice = _sizeAdvisor.advise(product, context.sizes);
    final List<String> facts = [
      if (lead != null) lead,
      if (product.brand != null) '${product.brand}, рейтинг ${_rating(product)}',
      if (product.material != null) product.material!,
      if (advice != null) 'твой размер ${advice.size}',
      if (product.stock <= 5 && product.isAvailable) 'осталось ${product.stock} шт.',
    ];
    return ProductPick(
      product: product,
      reason: facts.join(' · '),
      size: advice?.size,
    );
  }

  List<String> _followUps(Sport sport) => [
        'Собери комплект для ${_genitive(sport)}',
        'Какой размер мне подойдёт?',
        'Сравни обувь',
        'Что купить до 20 000 ₸?',
      ];

  static String _rating(Product product) =>
      product.rating == null ? '—' : product.rating!.toStringAsFixed(1).replaceAll('.', ',');

  static double _roundBudget(double value) => (value / 5000).ceil() * 5000;

  static String _genitive(Sport sport) => switch (sport.name) {
        'Волейбол' => 'волейбола',
        'Бег' => 'бега',
        'Футбол' => 'футбола',
        'Плавание' => 'плавания',
        'Бокс' => 'бокса',
        'Карате' => 'карате',
        'Баскетбол' => 'баскетбола',
        'Йога' => 'йоги',
        'Фитнес' => 'фитнеса',
        _ => 'спорта «${sport.name}»',
      };

  static String _normalize(String text) =>
      text.toLowerCase().replaceAll('ё', 'е').trim();

  static bool _hasAny(String text, List<String> stems) =>
      stems.any(text.contains);
}

class _Query {
  const _Query({
    required this.text,
    required this.sport,
    required this.sportMentioned,
    required this.category,
    required this.level,
    required this.budget,
    required this.wantsCheap,
    required this.named,
  });

  final String text;
  final Sport? sport;

  /// Вид спорта назван в самом сообщении, а не взят из профиля или истории.
  final bool sportMentioned;
  final String? category;
  final SportLevel level;
  final double? budget;
  final bool wantsCheap;
  final List<Product> named;

  /// В запросе есть признаки поиска товара: название, категория, цена.
  bool get hasProductSignal =>
      category != null ||
      budget != null ||
      wantsCheap ||
      (named.isNotEmpty && named.length <= 6);
}
