import 'dart:math' as math;

import '../search/search_matcher.dart';

/// Что нашла автопроверка и где.
class RiskReason {
  const RiskReason(this.label, this.fragment, this.score);

  /// Что не так: «Слово о наркотиках», «Контакт для сделки вне магазина».
  final String label;

  /// Кусок текста вокруг находки — администратор видит его сразу.
  final String fragment;
  final int score;

  Map<String, Object?> toJson() => {'label': label, 'fragment': fragment, 'score': score};

  static RiskReason fromJson(Map<String, Object?> json) => RiskReason(
        json['label']! as String,
        (json['fragment'] as String?) ?? '',
        (json['score'] as int?) ?? 0,
      );
}

/// Итог проверки товара.
class RiskReport {
  const RiskReport(this.reasons);

  final List<RiskReason> reasons;

  int get score => math.min(100, reasons.fold(0, (sum, r) => sum + r.score));

  /// Скрыть до проверки администратором.
  bool get hold => score >= ContentChecker.holdScore;

  /// Показывать, но поставить в очередь администратору.
  bool get flag => score >= ContentChecker.flagScore;
}

/// Автоматическая проверка карточки товара: администратор не может
/// прочитать каждое описание до конца, а запрещённое прячут — в самом
/// низу описания, буквами через пробел, латиницей вперемешку
/// с кириллицей, эмодзи-кодами, ссылкой на мессенджер.
///
/// Это правила, а не нейросеть: работает на телефоне, без интернета
/// и мгновенно. Решение всё равно принимает человек — проверка только
/// не пускает в каталог явное и ставит сомнительное в очередь.
class ContentChecker {
  ContentChecker._();

  /// Столько баллов — товар скрыт до решения администратора.
  static const int holdScore = 60;

  /// Столько — товар виден, но администратор должен посмотреть.
  static const int flagScore = 25;

  /// Слова (основы), которых не бывает в спортивном магазине.
  /// Сильные — сразу на проверку; ищутся и в склеенном тексте
  /// («м е ф е д р о н», «м.е.ф.е.д.р.о.н»).
  static const Map<String, List<String>> _strong = {
    'Наркотики': [
      'мефедрон', 'амфетамин', 'метамфетамин', 'гашиш', 'марихуан',
      'каннабис', 'канабис', 'кокаин', 'героин', 'метадон', 'экстази',
      'закладк', 'кладмен', 'гидропон', 'насвай', 'спайс', 'альфапвп',
      'mdma', 'мдма', 'alphapvp', 'apvp', 'mephedrone', 'cocaine',
    ],
    'Допинг (запрещён в спорте)': [
      'стероид', 'анаболик', 'тестостерон', 'нандролон', 'станозолол',
      'оксандролон', 'кленбутерол', 'тренболон', 'болденон', 'дианабол',
      'мельдони', 'эритропоэтин', 'гормонроста', 'steroid', 'sarms',
    ],
    'Оружие': ['кастет', 'огнестрел', 'глушител', 'патрон'],
  };

  /// Короткие слова — только целым словом, иначе ложные срабатывания.
  static const Map<String, List<String>> _shortWords = {
    'Наркотики (сленг)': ['меф', 'мефчик', 'гаш', 'бошки', 'лсд', 'lsd', 'кокс'],
    'Лекарства без рецепта': [
      'трамадол', 'лирика', 'прегабалин', 'тропикамид', 'феназепам',
    ],
    'Допинг (запрещён в спорте)': ['сарм', 'сармы'],
    // «Травматизм» — обычное слово, поэтому оружие — только целым словом.
    'Оружие': ['травмат', 'травматы', 'травматик'],
  };

  /// Средние баллы: сами по себе не преступление, но так уводят сделку.
  static final List<(String, RegExp, int)> _patterns = [
    ('Продажа без рецепта', RegExp(r'без\s+рецепт'), 40),
    ('Контакт для сделки вне магазина',
        RegExp(r't\.me/|telegram|телеграм|телег[аеу]|(?<![a-zа-я])тг(?![a-zа-я])|whats\s?app|ватсап|вацап|wa\.me|в\s+личк|в\s+лс(?![a-zа-я])'), 35),
    ('Ник в мессенджере', RegExp(r'(^|\s)@[a-z0-9_]{4,}'), 35),
    ('Номер телефона в описании',
        RegExp(r'(\+7|\b8)[\s\-(]*\d{3}[\s\-)]*\d{3}[\s\-]*\d{2}[\s\-]*\d{2}'), 30),
    ('Ссылка на сторонний сайт', RegExp(r'https?://|www\.|\.(ru|kz|com|onion)\b'), 25),
    ('Оплата в обход магазина', RegExp(r'крипт|btc|usdt|биткоин|предоплат'), 25),
  ];

  /// Эмодзи, которыми в объявлениях обозначают наркотики.
  static const List<String> _emoji = ['❄', '🍁', '🌿', '💊', '🍄', '💉', '🧂', '💎', '🔮'];

  /// Латинские буквы, похожие на русские, и цифры вместо букв:
  /// «мeфeдpoн» (с латинскими e, p, o), «м3ф».
  static const Map<String, String> _lookalikes = {
    'a': 'а', 'c': 'с', 'e': 'е', 'k': 'к', 'm': 'м', 'o': 'о', 'p': 'р',
    't': 'т', 'x': 'х', 'y': 'у', 'h': 'н', 'b': 'в', '0': 'о', '3': 'з',
    '@': 'а', 'ё': 'е',
  };

  static final RegExp _invisible = RegExp('[­​-‏⁠﻿]');

  /// Текст «как его прочтёт человек»: без невидимых символов, со
  /// схожими латинскими буквами и цифрами, заменёнными на русские.
  static String toCyrillic(String text) {
    final StringBuffer out = StringBuffer();
    for (final String ch in text.toLowerCase().replaceAll(_invisible, '').split('')) {
      out.write(_lookalikes[ch] ?? ch);
    }
    return out.toString();
  }

  /// Только буквы подряд — так находятся слова, разбитые пробелами,
  /// точками и звёздочками.
  static String squash(String text) =>
      text.replaceAll(RegExp(r'[^a-zа-я]'), '');

  /// Иносказания: каждое слово обычное, вместе — объявление.
  static const List<String> _phrases = [
    'белыйпорошок', 'порошокбелый', 'белаяпудра', 'белыекристаллы',
    'белыйкристалл', 'кристаллыбелые', 'соливанн', 'солидляванн',
  ];

  /// Что пишут покупатели в отзывах и вопросах, если товар — прикрытие.
  static const List<String> _buyerDrugs = [
    'наркот', 'наркоман', 'наркош', 'нарик', 'закладк', 'кладмен', 'барыг',
  ];
  static const List<String> _buyerFraud = ['мошенн', 'обман', 'подделк', 'развод', 'кидал'];

  /// [medianPrice] — средняя цена в той же категории (для сравнения).
  /// [extra] — другие тексты о товаре: отзывы и вопросы покупателей,
  /// текст на фото. [category] — категория («Спортивное питание»).
  /// [ordersLastDay] — сколько раз товар купили за последние сутки.
  static RiskReport check({
    required String name,
    String? description,
    String? composition,
    String? material,
    String? brand,
    String? category,
    required double price,
    double? medianPrice,
    List<(String, String)> extra = const [],
    int ordersLastDay = 0,
  }) {
    final List<RiskReason> reasons = _scanText(
      [name, brand ?? '', description ?? '', composition ?? '', material ?? ''].join('\n'),
    );
    for (final (String where, String text) in extra) {
      final bool buyers = where.contains('покупател');
      reasons.addAll(_scanText(text, where: where, buyers: buyers));
    }
    final String all = toCyrillic(
      [name, description ?? '', composition ?? '', material ?? ''].join(' '),
    );
    // «Синтетика» у протеина — не ткань, а сленговое название наркотиков.
    final bool nutrition = (category ?? '').toLowerCase().contains('питани');
    if (nutrition && all.contains('синтет')) {
      reasons.add(RiskReason(
        '«Синтетика» у спортивного питания — так называют синтетические наркотики',
        material != null && material.toLowerCase().contains('синтет')
            ? 'Материал: $material'
            : _around(all, all.indexOf('синтет'), 7),
        40,
      ));
    }
    // Дробные граммы («0,5 г», «1.5 гр») — дозировки, а не порции.
    final RegExpMatch? dose = RegExp(r'(?<![\d.,])(0[.,]\d+|[1-9][.,]\d+)\s*(г|гр|g)(?![a-zа-я])')
        .firstMatch(all);
    if (nutrition && dose != null) {
      reasons.add(RiskReason('Дробная дозировка в граммах', _around(all, dose.start, dose.end - dose.start), 15));
    }
    if (medianPrice != null && medianPrice > 0) {
      if (price < medianPrice * 0.25 || price > medianPrice * 5) {
        reasons.add(RiskReason(
          price < medianPrice ? 'Цена подозрительно низкая' : 'Цена подозрительно высокая',
          '${price.round()} ₸ при обычной ~${medianPrice.round()} ₸ в этой категории',
          20,
        ));
      }
    }
    if (ordersLastDay >= 5) {
      reasons.add(RiskReason(
        'Необычно много покупок за сутки',
        '$ordersLastDay заказов за 24 часа',
        15,
      ));
    }
    return RiskReport(reasons);
  }

  static String _around(String haystack, int at, int length) {
    if (at < 0) return '';
    final int from = math.max(0, at - 30);
    final int to = math.min(haystack.length, at + length + 30);
    return '${from > 0 ? '…' : ''}${haystack.substring(from, to).replaceAll('\n', ' ').trim()}'
        '${to < haystack.length ? '…' : ''}';
  }

  /// Проверка одного текста. [where] — откуда он («в отзывах
  /// покупателей», «на фото товара»): попадает в подпись находки.
  /// [buyers] — текст покупателей: ищем и их жалобы.
  static List<RiskReason> _scanText(String text, {String? where, bool buyers = false}) {
    // «Нестероидный» (обычная мазь от ушибов) — не допинг.
    final String raw =
        text.replaceAll(RegExp('нестероидн', caseSensitive: false), 'н-с-в-п');
    final String lower = raw.toLowerCase().replaceAll(_invisible, '');
    final String cyr = toCyrillic(raw);
    final String squashedCyr = squash(cyr);
    final String squashedLat = squash(lower);
    // Латиница «на слух»: «porosho.k» = «порошок», «mefedron» = «мефедрон».
    final String heard = SearchMatcher.simplify(lower);
    final List<RiskReason> reasons = [];
    final Set<String> found = {};
    String place(String label, int at) {
      if (where != null) return '$label — $where';
      return at >= 0 && raw.length > 200 && at > raw.length * 0.8
          ? '$label — спрятано в конце описания'
          : label;
    }

    void add(String label, String term, int score) {
      if (!found.add('$label:$term')) return;
      int at = RegExp('(^|[^a-zа-я])$term').firstMatch(cyr)?.start ?? -1;
      if (at < 0) at = lower.indexOf(term);
      if (at < 0) {
        // Слово разбито пробелами — показываем место по первой букве.
        final RegExpMatch? spacedAt =
            RegExp(term.split('').join(r'[\s.*_\-\u200b]*')).firstMatch(cyr);
        at = spacedAt?.start ?? -1;
      }
      reasons.add(RiskReason(
        place(label, at),
        at >= 0
            ? _around(raw, at, term.length)
            : '«$term» (записано латиницей, через пробелы или символы)',
        score,
      ));
    }

    bool contains(String term) {
      if (squashedCyr.contains(term) || squashedLat.contains(term)) return true;
      final String heardTerm = SearchMatcher.simplify(term);
      return heardTerm.length >= 6 && heard.contains(heardTerm);
    }

    for (final MapEntry<String, List<String>> group in _strong.entries) {
      for (final String term in group.value) {
        if (contains(term)) add(group.key, term, buyers ? 30 : 60);
      }
    }
    for (final String term in _phrases) {
      if (contains(term)) add('Иносказание о наркотиках', term, buyers ? 30 : 60);
    }
    if (buyers) {
      for (final String term in _buyerDrugs) {
        if (contains(term)) {
          add('Покупатели пишут о наркотиках', term, 30);
          break;
        }
      }
      for (final String term in _buyerFraud) {
        if (contains(term)) {
          add('Покупатели жалуются на обман', term, 20);
          break;
        }
      }
    }
    final Set<String> words = {
      ...RegExp(r'[a-zа-я]+').allMatches(cyr).map((m) => m.group(0)!),
      ...RegExp(r'[a-zа-я]+').allMatches(lower).map((m) => m.group(0)!),
    };
    // Буквы через пробел («м е ф и …») склеиваем: короткое слово
    // ищется внутри склейки.
    final List<String> spacedRuns = [
      for (final RegExpMatch m
          in RegExp(r'(?<![a-zа-я])(?:[a-zа-я][\s.*_\-]+){2,}[a-zа-я](?![a-zа-я])').allMatches(cyr))
        squash(m.group(0)!),
    ];
    for (final MapEntry<String, List<String>> group in _shortWords.entries) {
      for (final String term in group.value) {
        if (words.contains(term) || spacedRuns.any((run) => run.contains(term))) {
          add(group.key, term, buyers ? 20 : 40);
        }
      }
    }
    // Контакты и ссылки в отзывах — обычное дело, у продавца и на фото — нет.
    if (!buyers) {
      for (final (String label, RegExp pattern, int score) in _patterns) {
        final RegExpMatch? match = pattern.firstMatch(lower) ?? pattern.firstMatch(cyr);
        if (match == null) continue;
        reasons.add(RiskReason(
          place(label, match.start),
          _around(raw, match.start, match.end - match.start),
          score,
        ));
      }
    }
    final List<String> emoji = [for (final String e in _emoji) if (raw.contains(e)) e];
    if (emoji.isNotEmpty) {
      reasons.add(RiskReason(
        place('Эмодзи, которыми обозначают наркотики', -1),
        emoji.join(' '),
        math.min(50, 25 * emoji.length),
      ));
    }
    // Буквы через пробел («м е ф»): обычный продавец так не пишет.
    final RegExpMatch? spaced =
        RegExp(r'(?<![a-zа-я])(?:[a-zа-я][\s.*_\-]+){3,}[a-zа-я](?![a-zа-я])').firstMatch(cyr);
    if (spaced != null && !buyers) {
      reasons.add(RiskReason(
        place('Слово разбито на буквы — так прячут от поиска', spaced.start),
        _around(raw, spaced.start, spaced.end - spaced.start),
        15,
      ));
    }
    return reasons;
  }
}
