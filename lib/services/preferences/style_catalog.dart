import 'dart:ui' show Color;

/// Цвет для анкеты: ключ, название, образец.
class ColorChoice {
  const ColorChoice(this.key, this.name, this.sample);

  final String key;
  final String name;
  final Color sample;
}

/// Материал для анкеты: ключ, название, слова в описании материала товара.
class MaterialChoice {
  const MaterialChoice(this.key, this.name, this.hint, this.keywords);

  final String key;
  final String name;
  final String hint;
  final List<String> keywords;
}

/// Что нужно игроку на позиции: слова в названии товара и причина.
class PositionNeed {
  const PositionNeed(this.keywords, this.reason);

  /// Подходит товар, в названии которого есть любое из слов.
  final List<String> keywords;
  final String reason;

  bool matches(String productName) {
    final String name = productName.toLowerCase();
    return keywords.any(name.contains);
  }
}

/// Позиция (амплуа, дистанция, стиль) в виде спорта.
class SportPosition {
  const SportPosition(this.key, this.title, this.about, this.needs);

  final String key;
  final String title;

  /// Чем позиция особенная — одна фраза для анкеты.
  final String about;
  final List<PositionNeed> needs;
}

/// Справочник анкеты: цвета, материалы и позиции во всех видах спорта
/// каталога. Позиции подобраны по реальной специфике: либеро чаще всех
/// падает на пол, вратарю нужны перчатки, марафонцу — вода и пояс.
class StyleCatalog {
  StyleCatalog._();

  static const List<ColorChoice> colors = [
    ColorChoice('black', 'Чёрный', Color(0xFF1B1B1F)),
    ColorChoice('white', 'Белый', Color(0xFFF4F4F2)),
    ColorChoice('gray', 'Серый', Color(0xFF8E939B)),
    ColorChoice('red', 'Красный', Color(0xFFD7262B)),
    ColorChoice('pink', 'Розовый', Color(0xFFE85A9B)),
    ColorChoice('orange', 'Оранжевый', Color(0xFFF07A22)),
    ColorChoice('yellow', 'Жёлтый', Color(0xFFF2C21A)),
    ColorChoice('green', 'Зелёный', Color(0xFF2FA35A)),
    ColorChoice('lightblue', 'Голубой', Color(0xFF39B7E0)),
    ColorChoice('blue', 'Синий', Color(0xFF2849B8)),
    ColorChoice('purple', 'Фиолетовый', Color(0xFF7B3FA8)),
    ColorChoice('brown', 'Коричневый', Color(0xFF7A4A2A)),
  ];

  static const List<MaterialChoice> materials = [
    MaterialChoice('cotton', 'Хлопок', 'Мягкий, «дышит», приятен коже',
        ['хлопок']),
    MaterialChoice('synthetic', 'Синтетика', 'Быстро сохнет, не тянется',
        ['полиэстер', 'полиамид', 'нейлон', 'эластан', 'спандекс', 'микрофибра']),
    MaterialChoice('natural', 'Натуральное', 'Кожа, пробка, резина',
        ['кожа', 'пробк', 'резин', 'латекс']),
  ];

  static ColorChoice? colorByKey(String key) {
    for (final ColorChoice color in colors) {
      if (color.key == key) return color;
    }
    return null;
  }

  static MaterialChoice? materialByKey(String key) {
    for (final MaterialChoice material in materials) {
      if (material.key == key) return material;
    }
    return null;
  }

  /// Позиции по названию вида спорта (как в каталоге).
  static const Map<String, List<SportPosition>> positions = {
    'Волейбол': [
      SportPosition('libero', 'Либеро', 'Принимает подачи и чаще всех падает за мячом', [
        PositionNeed(['наколенник'], 'Либеро постоянно в падениях — колени нужно защитить'),
        PositionNeed(['кроссовки для волейбола'], 'Низкая стойка и рывки — нужна устойчивая подошва'),
        PositionNeed(['форма'], 'Либеро играет в форме другого цвета — возьми второй комплект'),
        PositionNeed(['шорты волейбольные'], 'Эластичные шорты не мешают падать'),
      ]),
      SportPosition('setter', 'Связующий', 'Делает передачи на атаку, много работает пальцами', [
        PositionNeed(['мяч'], 'Свой мяч — отрабатывать передачи у стены'),
        PositionNeed(['кроссовки для волейбола'], 'Быстрые перемещения под мяч'),
        PositionNeed(['наколенник'], 'Страховка при доводке мяча в падении'),
      ]),
      SportPosition('outside', 'Доигровщик', 'Атакует и принимает — универсал', [
        PositionNeed(['кроссовки для волейбола'], 'Много прыжков — нужна амортизация'),
        PositionNeed(['фиксатор', 'наколенник'], 'Прыжки и падения нагружают колени'),
        PositionNeed(['форма'], 'Игровая форма на турниры'),
      ]),
      SportPosition('opposite', 'Диагональный', 'Главный атакующий, сильные прыжки', [
        PositionNeed(['фиксатор'], 'После приземлений колену нужна поддержка'),
        PositionNeed(['кроссовки для волейбола'], 'Амортизация для мощных прыжков'),
      ]),
      SportPosition('middle', 'Центральный блокирующий', 'Блок и быстрая атака у сетки', [
        PositionNeed(['фиксатор'], 'Больше всех прыгает на блок — колени под нагрузкой'),
        PositionNeed(['кроссовки для волейбола'], 'Взрывные прыжки с места'),
      ]),
    ],
    'Футбол': [
      SportPosition('goalkeeper', 'Вратарь', 'Ловит мяч руками, прыгает и падает', [
        PositionNeed(['вратарск'], 'Без вратарских перчаток мяч выскальзывает и травмирует пальцы'),
        PositionNeed(['бутсы'], 'Сцепление с газоном для прыжков'),
        PositionNeed(['мяч'], 'Свой мяч для тренировки ловли'),
      ]),
      SportPosition('defender', 'Защитник', 'Отбор мяча, жёсткие стыки', [
        PositionNeed(['щитки'], 'В отборах больше всего ударов по голени'),
        PositionNeed(['гетры'], 'Удерживают щитки на месте'),
        PositionNeed(['бутсы'], 'Устойчивость в единоборствах'),
      ]),
      SportPosition('midfielder', 'Полузащитник', 'Больше всех бегает по полю', [
        PositionNeed(['бутсы'], 'Лёгкие бутсы на 10+ км за игру'),
        PositionNeed(['футболка тренировочная'], 'Ткань, отводящая пот, — бег весь матч'),
        PositionNeed(['щитки'], 'Защита в борьбе за мяч'),
      ]),
      SportPosition('forward', 'Нападающий', 'Удары по воротам и рывки', [
        PositionNeed(['бутсы'], 'Точный удар начинается с бутс'),
        PositionNeed(['мяч'], 'Отрабатывать удары по воротам'),
        PositionNeed(['шорты для футбола'], 'Лёгкие шорты для рывков'),
      ]),
    ],
    'Баскетбол': [
      SportPosition('pg', 'Разыгрывающий', 'Ведёт мяч и раздаёт передачи', [
        PositionNeed(['баскетбольный мяч'], 'Свой мяч — каждый день работать над дриблингом'),
        PositionNeed(['баскетбольные кроссовки'], 'Резкие смены направления'),
      ]),
      SportPosition('sg', 'Атакующий защитник', 'Бросает издалека', [
        PositionNeed(['баскетбольные кроссовки'], 'Стабильная опора при броске'),
        PositionNeed(['баскетбольная форма'], 'Свободный крой не сковывает бросок'),
      ]),
      SportPosition('forward', 'Форвард', 'Атака и подбор, много прыжков', [
        PositionNeed(['баскетбольные кроссовки'], 'Амортизация для прыжков за подбором'),
        PositionNeed(['фиксатор'], 'Колени под нагрузкой в прыжках'),
      ]),
      SportPosition('center', 'Центровой', 'Борьба под кольцом', [
        PositionNeed(['баскетбольные кроссовки'], 'Высокие кроссовки держат голеностоп в толкотне'),
        PositionNeed(['фиксатор', 'наколенник'], 'Самые тяжёлые приземления — у центровых'),
      ]),
    ],
    'Бег': [
      SportPosition('sprint', 'Спринт', 'Короткие дистанции, максимальная скорость', [
        PositionNeed(['кроссовки'], 'Лёгкие кроссовки для старта'),
        PositionNeed(['тайтсы', 'шорты'], 'Компрессия разогревает мышцы'),
      ]),
      SportPosition('middle', 'Средние дистанции', '5–10 км, регулярные пробежки', [
        PositionNeed(['кроссовки'], 'Амортизация на каждый день'),
        PositionNeed(['футболка'], 'Футболка, которая быстро сохнет'),
        PositionNeed(['часы'], 'Следить за темпом и пульсом'),
      ]),
      SportPosition('marathon', 'Марафон', 'Длинные дистанции, часы в пути', [
        PositionNeed(['пояс'], 'Телефон и гели на теле, руки свободны'),
        PositionNeed(['бутылка'], 'Вода на длинной тренировке'),
        PositionNeed(['шорты беговые 2 в 1'], 'Внутренние шорты — ничего не натирает за 42 км'),
        PositionNeed(['рукава'], 'Защита от солнца на долгом забеге'),
        PositionNeed(['часы'], 'Держать ровный темп'),
      ]),
    ],
    'Бокс': [
      SportPosition('beginner', 'Тренировки', 'Работа на снарядах и в парах', [
        PositionNeed(['перчатки'], 'Защищают кисти и партнёра'),
        PositionNeed(['бинты'], 'Фиксируют запястье под перчаткой'),
      ]),
      SportPosition('sparring', 'Спарринги и соревнования', 'Контактные бои', [
        PositionNeed(['капа'], 'В спарринге без капы нельзя'),
        PositionNeed(['бинты'], 'Обязательны на соревнованиях'),
        PositionNeed(['перчатки'], 'Мягкие перчатки для спарринга'),
      ]),
    ],
    'Карате': [
      SportPosition('kata', 'Ката', 'Формальные комплексы, важен внешний вид', [
        PositionNeed(['кимоно для карате классическое'], 'Плотное кимоно красиво «хлопает» в ката'),
        PositionNeed(['пояс'], 'Пояс по твоему уровню'),
      ]),
      SportPosition('kumite', 'Кумитэ', 'Поединки', [
        PositionNeed(['кимоно для карате'], 'Лёгкое кимоно не мешает двигаться'),
        PositionNeed(['капа'], 'Защита зубов в поединке'),
      ]),
      SportPosition('kyokushin', 'Киокушинкай', 'Полный контакт', [
        PositionNeed(['киокушинкай'], 'Кимоно с укороченным рукавом для киокушина'),
        PositionNeed(['капа'], 'Полный контакт — нужна капа'),
      ]),
    ],
    'Плавание': [
      SportPosition('fitness', 'Для себя', 'Бассейн 2–3 раза в неделю', [
        PositionNeed(['набор для плавания', 'очки', 'шапочка'], 'Очки и шапочка — минимум для бассейна'),
        PositionNeed(['купальник'], 'Хлоростойкая ткань служит дольше'),
      ]),
      SportPosition('sport', 'Спортивное плавание', 'Тренировки на время и соревнования', [
        PositionNeed(['очки'], 'Очки, которые не запотевают на всю тренировку'),
        PositionNeed(['купальник'], 'Спортивный купальник снижает сопротивление'),
        PositionNeed(['шапочка'], 'Силиконовая шапочка — минус секунды'),
      ]),
    ],
    'Йога': [
      SportPosition('hatha', 'Хатха', 'Спокойная практика, удержание асан', [
        PositionNeed(['коврик'], 'Нескользящий коврик для долгих асан'),
        PositionNeed(['блок'], 'Блок помогает в сложных позах'),
      ]),
      SportPosition('dynamic', 'Динамическая (виньяса)', 'Связки в движении, много пота', [
        PositionNeed(['коврик'], 'Коврик, который не скользит от пота'),
        PositionNeed(['леггинсы', 'комплект для фитнеса'], 'Тянущаяся одежда не мешает переходам'),
      ]),
    ],
    'Фитнес': [
      SportPosition('strength', 'Силовые', 'Свободные веса и тренажёры', [
        PositionNeed(['гиря', 'гантели'], 'Свой вес для тренировок дома'),
        PositionNeed(['кроссовки для зала'], 'Плоская устойчивая подошва для приседаний'),
        PositionNeed(['наколенник'], 'Поддержка коленей на тяжёлых подходах'),
      ]),
      SportPosition('functional', 'Функциональные и кардио', 'Круговые, интервалы', [
        PositionNeed(['бутылка'], 'Пить между раундами'),
        PositionNeed(['футболка', 'комплект для фитнеса'], 'Одежда, которая отводит пот'),
        PositionNeed(['кроссовки для зала'], 'Прыжки и смены направления'),
      ]),
    ],
  };

  static List<SportPosition> positionsFor(String? sportName) =>
      positions[sportName] ?? const [];

  static SportPosition? position(String? sportName, String? key) {
    for (final SportPosition position in positionsFor(sportName)) {
      if (position.key == key) return position;
    }
    return null;
  }
}
