import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/password_hasher.dart';
import '../../models/enums.dart';
import '../../models/sport.dart';
import 'database_schema.dart';
import 'seed_athletes.dart';
import 'seed_products_extra.dart';
import 'seed_reviews.dart';
import 'seed_exhibits.dart';

/// Демонстрационные данные, которые записываются в SQLite
/// при первом запуске приложения.
///
/// Записи связываются по текстовым ключам ('volleyball', 'knee_pads'),
/// а реальные id берутся из результата INSERT — так в данных нет
/// «магических» чисел и их легко дополнять.
class SeedData {
  SeedData._();

  static const String _imagesFolder = 'assets/images/products';
  static const String _clothes = 'XS,S,M,L,XL';
  static const String _shoes = '36,37,38,39,40,41,42,43,44,45';

  // ---------------------------------------------------------------------------
  // Виды спорта (как на экране ии2): ключ, название, описание
  // ---------------------------------------------------------------------------
  static const List<(String, String, String)> _sports = [
    ('volleyball', 'Волейбол', 'Командная игра с мячом через сетку'),
    ('running', 'Бег', 'Пробежки, марафоны и беговые тренировки'),
    ('football', 'Футбол', 'Командная игра с мячом на поле'),
    ('swimming', 'Плавание', 'Тренировки в бассейне и открытой воде'),
    ('boxing', 'Бокс', 'Ударный вид единоборств'),
    ('karate', 'Карате', 'Японское боевое искусство'),
    ('basketball', 'Баскетбол', 'Командная игра с мячом и кольцом'),
    ('yoga', 'Йога', 'Практики гибкости, баланса и дыхания'),
    ('fitness', 'Фитнес', 'Силовые и функциональные тренировки в зале'),
  ];

  // ---------------------------------------------------------------------------
  // Категории (общие для всех видов спорта, sport_id = NULL)
  // ---------------------------------------------------------------------------
  static const List<(String, String)> _categories = [
    ('clothes', 'Одежда'),
    ('shoes', 'Обувь'),
    ('accessories', 'Аксессуары'),
    ('protection', 'Защита'),
    ('equipment', 'Инвентарь'),
  ];

  // ---------------------------------------------------------------------------
  // Товары: ключ (= имя файла картинки), название, описание, цена ₸,
  // категория, вид спорта, размеры, остаток на складе
  // ---------------------------------------------------------------------------
  static const List<(String, String, String, int, String, String, String?, int)>
      _products = [
    // Волейбол
    ('volleyball_uniform', 'Волейбольная форма',
        'Комплект из майки и шорт из дышащей ткани с быстрым отводом влаги.',
        6990, 'clothes', 'volleyball', _clothes, 12),
    ('volleyball_knee_pads', 'Наколенники волейбольные',
        'Мягкие наколенники защищают колени при падениях и приёмах мяча.',
        1500, 'protection', 'volleyball', 'S,M,L', 25),
    ('volleyball_shoes', 'Кроссовки для волейбола',
        'Лёгкие кроссовки с амортизацией и нескользящей подошвой для зала.',
        18990, 'shoes', 'volleyball', _shoes, 8),
    ('volleyball_shorts', 'Шорты волейбольные',
        'Эластичные шорты, не сковывают движения в прыжке.',
        2900, 'clothes', 'volleyball', _clothes, 20),
    ('knee_brace', 'Фиксатор на колени',
        'Поддерживает коленный сустав при высоких нагрузках.',
        2300, 'protection', 'volleyball', 'S,M,L', 15),
    ('mikasa_ball', 'Профессиональный мяч MIKASA',
        'Официальный мяч соревнований: точный полёт и мягкое касание.',
        29990, 'equipment', 'volleyball', null, 6),
    ('mikasa_backpack', 'Рюкзак Mikasa',
        'Вместительный рюкзак с отделением для мяча и обуви.',
        12990, 'accessories', 'volleyball', null, 5),

    // Бег
    ('running_shoes', 'Кроссовки для бега',
        'Беговые кроссовки с амортизирующей подошвой для асфальта.',
        45990, 'shoes', 'running', _shoes, 10),
    ('running_tshirt', 'Беговая футболка',
        'Лёгкая футболка из дышащей сетки, быстро сохнет.',
        5990, 'clothes', 'running', _clothes, 18),
    ('running_tights', 'Тайтсы беговые',
        'Компрессионные тайтсы поддерживают мышцы на длинных дистанциях.',
        8990, 'clothes', 'running', _clothes, 14),
    ('running_belt', 'Беговой пояс для телефона',
        'Пояс с карманом для телефона и ключей, не болтается при беге.',
        3490, 'accessories', 'running', null, 20),
    ('sport_watch', 'Спортивные часы с пульсометром',
        'GPS, пульс, темп и план тренировок прямо на запястье.',
        39990, 'accessories', 'running', null, 4),

    // Футбол
    ('football_boots', 'Бутсы футбольные',
        'Бутсы с шипами для натурального и искусственного газона.',
        24990, 'shoes', 'football', '38,39,40,41,42,43,44,45', 9),
    ('shin_guards', 'Щитки футбольные',
        'Защищают голень от ударов, крепятся фиксатором.',
        3990, 'protection', 'football', 'S,M,L', 22),
    ('football_socks', 'Гетры футбольные',
        'Плотные гетры, удерживают щитки на месте.',
        1990, 'clothes', 'football', 'S,M,L', 30),
    ('football_shorts', 'Шорты для футбола',
        'Лёгкие шорты с эластичным поясом.',
        3490, 'clothes', 'football', _clothes, 16),
    ('football_ball', 'Футбольный мяч Adidas',
        'Мяч 5 размера для тренировок и игр.',
        12990, 'equipment', 'football', null, 11),
    ('goalkeeper_gloves', 'Вратарские перчатки',
        'Перчатки с латексным покрытием для надёжного хвата мяча.',
        9990, 'accessories', 'football', '7,8,9,10', 6),

    // Фитнес
    ('sport_tshirt', 'Спортивная футболка',
        'Универсальная футболка для зала из дышащей ткани.',
        4990, 'clothes', 'fitness', _clothes, 25),
    ('adidas_pants', 'Штаны Adidas',
        'Спортивные штаны свободного кроя с карманами на молнии.',
        14990, 'clothes', 'fitness', _clothes, 10),
    ('gym_shoes', 'Кроссовки для зала',
        'Устойчивая подошва для силовых и функциональных тренировок.',
        22990, 'shoes', 'fitness', _shoes, 9),
    ('kettlebell', 'Гиря 8 кг',
        'Литая гиря с удобной рукоятью.',
        6990, 'equipment', 'fitness', null, 12),
    ('dumbbells', 'Гантели 2 × 5 кг',
        'Пара гантелей с прорезиненным покрытием.',
        11990, 'equipment', 'fitness', null, 8),
    ('water_bottle', 'Бутылка для тренировок',
        'Бутылка 750 мл с удобным клапаном.',
        1990, 'accessories', 'fitness', null, 40),

    // Баскетбол
    ('basketball_ball', 'Баскетбольный мяч Spalding',
        'Мяч 7 размера с хорошим сцеплением.',
        14990, 'equipment', 'basketball', null, 10),
    ('basketball_shoes', 'Баскетбольные кроссовки',
        'Высокие кроссовки фиксируют голеностоп при прыжках.',
        39990, 'shoes', 'basketball', _shoes, 7),
    ('basketball_uniform', 'Баскетбольная форма',
        'Майка и шорты свободного кроя.',
        8990, 'clothes', 'basketball', _clothes, 12),

    // Плавание
    ('swim_goggles', 'Очки для плавания',
        'Очки с защитой от запотевания и UV-фильтром.',
        4490, 'accessories', 'swimming', null, 20),
    ('swim_cap', 'Шапочка для плавания',
        'Силиконовая шапочка, защищает волосы от хлорки.',
        2490, 'accessories', 'swimming', null, 25),
    ('swimsuit', 'Спортивный купальник',
        'Купальник из хлоростойкой ткани для тренировок.',
        11990, 'clothes', 'swimming', 'XS,S,M,L', 10),

    // Бокс
    ('boxing_gloves', 'Боксёрские перчатки',
        'Перчатки из искусственной кожи с плотным наполнителем.',
        14990, 'accessories', 'boxing', '10oz,12oz,14oz,16oz', 9),
    ('hand_wraps', 'Бинты боксёрские',
        'Эластичные бинты 3,5 м защищают кисти.',
        1990, 'protection', 'boxing', null, 30),
    ('mouth_guard', 'Капа',
        'Термопластичная капа защищает зубы.',
        2490, 'protection', 'boxing', null, 20),

    // Карате
    ('karate_kimono', 'Кимоно для карате',
        'Хлопковое кимоно для тренировок.',
        15990, 'clothes', 'karate', '130,140,150,160,170,180,190', 10),
    ('karate_belt', 'Пояс для карате',
        'Прочный хлопковый пояс.',
        2990, 'accessories', 'karate', null, 20),

    // Йога
    ('yoga_mat', 'Коврик для йоги',
        'Нескользящий коврик толщиной 6 мм.',
        7990, 'accessories', 'yoga', null, 15),
    ('yoga_block', 'Блок для йоги',
        'Блок из лёгкой пены для сложных асан.',
        2990, 'accessories', 'yoga', null, 20),
    ('yoga_leggings', 'Леггинсы для йоги',
        'Мягкие леггинсы с высокой посадкой.',
        9990, 'clothes', 'yoga', 'XS,S,M,L,XL', 12),
  ];

  // ---------------------------------------------------------------------------
  // Характеристики для сравнения товаров: бренд, материал, рейтинг
  // ---------------------------------------------------------------------------
  static const Map<String, (String, String, double)> _productDetails = {
    'volleyball_uniform': ('Mizuno', 'Полиэстер 100%', 4.7),
    'volleyball_knee_pads': ('Asics', 'Нейлон, пена EVA', 4.6),
    'volleyball_shoes': ('Asics', 'Сетка, резина', 4.8),
    'volleyball_shorts': ('Mizuno', 'Полиэстер, эластан', 4.4),
    'knee_brace': ('McDavid', 'Неопрен', 4.5),
    'mikasa_ball': ('Mikasa', 'Микрофибра', 4.9),
    'mikasa_backpack': ('Mikasa', 'Полиэстер 600D', 4.6),
    'running_shoes': ('Nike', 'Сетка, пена', 4.8),
    'running_tshirt': ('Nike', 'Полиэстер 100%', 4.5),
    'running_tights': ('Under Armour', 'Полиэстер, эластан', 4.6),
    'running_belt': ('Kalenji', 'Неопрен', 4.3),
    'sport_watch': ('Garmin', 'Пластик, силикон', 4.9),
    'football_boots': ('Adidas', 'Синтетическая кожа', 4.7),
    'shin_guards': ('Nike', 'Пластик, пена EVA', 4.4),
    'football_socks': ('Adidas', 'Нейлон, эластан', 4.3),
    'football_shorts': ('Puma', 'Полиэстер 100%', 4.4),
    'football_ball': ('Adidas', 'Полиуретан', 4.7),
    'goalkeeper_gloves': ('Reusch', 'Латекс', 4.5),
    'sport_tshirt': ('Puma', 'Полиэстер 100%', 4.5),
    'adidas_pants': ('Adidas', 'Хлопок, полиэстер', 4.6),
    'gym_shoes': ('Reebok', 'Сетка, резина', 4.7),
    'kettlebell': ('Torneo', 'Чугун', 4.8),
    'dumbbells': ('Torneo', 'Сталь, резина', 4.7),
    'water_bottle': ('Demix', 'Тритан', 4.5),
    'basketball_ball': ('Spalding', 'Композитная кожа', 4.8),
    'basketball_shoes': ('Nike', 'Сетка, резина', 4.7),
    'basketball_uniform': ('Jogel', 'Полиэстер 100%', 4.4),
    'swim_goggles': ('Speedo', 'Поликарбонат, силикон', 4.6),
    'swim_cap': ('Arena', 'Силикон', 4.5),
    'swimsuit': ('Speedo', 'Полиамид, эластан', 4.6),
    'boxing_gloves': ('Everlast', 'Искусственная кожа', 4.7),
    'hand_wraps': ('Everlast', 'Хлопок, эластан', 4.5),
    'mouth_guard': ('Venum', 'Термопластик', 4.3),
    'karate_kimono': (SeedProductsExtra.kimonoSeller, 'Хлопок 100%', 4.6),
    'karate_belt': ('Adidas', 'Хлопок 100%', 4.5),
    'yoga_mat': ('Manduka', 'ТПЭ', 4.8),
    'yoga_block': ('Demix', 'Пена EVA', 4.4),
    'yoga_leggings': ('Nike', 'Полиамид, эластан', 4.7),
  };

  // ---------------------------------------------------------------------------
  // sport_requirements: вид спорта, уровень, товар, обязательный?
  // ---------------------------------------------------------------------------
  static const SportLevel _beginner = SportLevel.beginner;
  static const SportLevel _amateur = SportLevel.amateur;
  static const SportLevel _experienced = SportLevel.experienced;

  static const List<(String, SportLevel, String, bool)> _requirements = [
    // Волейбол
    ('volleyball', _beginner, 'volleyball_uniform', true),
    ('volleyball', _beginner, 'volleyball_knee_pads', true),
    ('volleyball', _beginner, 'volleyball_shoes', true),
    ('volleyball', _beginner, 'water_bottle', false),
    ('volleyball', _amateur, 'volleyball_uniform', true),
    ('volleyball', _amateur, 'volleyball_knee_pads', true),
    ('volleyball', _amateur, 'volleyball_shoes', true),
    ('volleyball', _amateur, 'volleyball_shorts', false),
    ('volleyball', _amateur, 'water_bottle', false),
    ('volleyball', _experienced, 'volleyball_uniform', true),
    ('volleyball', _experienced, 'volleyball_knee_pads', true),
    ('volleyball', _experienced, 'volleyball_shoes', true),
    ('volleyball', _experienced, 'water_bottle', true),
    ('volleyball', _experienced, 'knee_brace', false),

    // Бег
    ('running', _beginner, 'running_shoes', true),
    ('running', _beginner, 'running_tshirt', true),
    ('running', _beginner, 'water_bottle', false),
    ('running', _amateur, 'running_shoes', true),
    ('running', _amateur, 'running_tshirt', true),
    ('running', _amateur, 'running_tights', true),
    ('running', _amateur, 'running_belt', false),
    ('running', _experienced, 'running_shoes', true),
    ('running', _experienced, 'running_tshirt', true),
    ('running', _experienced, 'running_tights', true),
    ('running', _experienced, 'running_belt', false),

    // Футбол
    ('football', _beginner, 'football_boots', true),
    ('football', _beginner, 'shin_guards', true),
    ('football', _beginner, 'football_socks', true),
    ('football', _beginner, 'football_shorts', false),
    ('football', _amateur, 'football_boots', true),
    ('football', _amateur, 'shin_guards', true),
    ('football', _amateur, 'football_socks', true),
    ('football', _amateur, 'football_shorts', true),
    ('football', _experienced, 'football_boots', true),
    ('football', _experienced, 'shin_guards', true),
    ('football', _experienced, 'football_socks', true),
    ('football', _experienced, 'football_shorts', true),

    // Фитнес
    ('fitness', _beginner, 'sport_tshirt', true),
    ('fitness', _beginner, 'gym_shoes', true),
    ('fitness', _beginner, 'water_bottle', false),
    ('fitness', _amateur, 'sport_tshirt', true),
    ('fitness', _amateur, 'gym_shoes', true),
    ('fitness', _amateur, 'adidas_pants', false),
    ('fitness', _amateur, 'water_bottle', false),
    ('fitness', _experienced, 'sport_tshirt', true),
    ('fitness', _experienced, 'gym_shoes', true),
    ('fitness', _experienced, 'adidas_pants', false),

    // Баскетбол
    ('basketball', _beginner, 'basketball_shoes', true),
    ('basketball', _beginner, 'basketball_uniform', true),
    ('basketball', _beginner, 'basketball_ball', false),
    ('basketball', _amateur, 'basketball_shoes', true),
    ('basketball', _amateur, 'basketball_uniform', true),
    ('basketball', _amateur, 'basketball_ball', true),
    ('basketball', _experienced, 'basketball_shoes', true),
    ('basketball', _experienced, 'basketball_uniform', true),
    ('basketball', _experienced, 'basketball_ball', true),

    // Плавание
    ('swimming', _beginner, 'swimsuit', true),
    ('swimming', _beginner, 'swim_cap', true),
    ('swimming', _beginner, 'swim_goggles', true),
    ('swimming', _amateur, 'swimsuit', true),
    ('swimming', _amateur, 'swim_cap', true),
    ('swimming', _amateur, 'swim_goggles', true),
    ('swimming', _experienced, 'swimsuit', true),
    ('swimming', _experienced, 'swim_cap', true),
    ('swimming', _experienced, 'swim_goggles', true),

    // Бокс
    ('boxing', _beginner, 'boxing_gloves', true),
    ('boxing', _beginner, 'hand_wraps', true),
    ('boxing', _beginner, 'mouth_guard', false),
    ('boxing', _amateur, 'boxing_gloves', true),
    ('boxing', _amateur, 'hand_wraps', true),
    ('boxing', _amateur, 'mouth_guard', true),
    ('boxing', _experienced, 'boxing_gloves', true),
    ('boxing', _experienced, 'hand_wraps', true),
    ('boxing', _experienced, 'mouth_guard', true),

    // Карате
    ('karate', _beginner, 'karate_kimono', true),
    ('karate', _beginner, 'karate_belt', true),
    ('karate', _amateur, 'karate_kimono', true),
    ('karate', _amateur, 'karate_belt', true),
    ('karate', _experienced, 'karate_kimono', true),
    ('karate', _experienced, 'karate_belt', true),

    // Йога
    ('yoga', _beginner, 'yoga_mat', true),
    ('yoga', _beginner, 'yoga_leggings', false),
    ('yoga', _amateur, 'yoga_mat', true),
    ('yoga', _amateur, 'yoga_leggings', true),
    ('yoga', _amateur, 'yoga_block', false),
    ('yoga', _experienced, 'yoga_mat', true),
    ('yoga', _experienced, 'yoga_leggings', true),
    ('yoga', _experienced, 'yoga_block', true),
  ];

  // ---------------------------------------------------------------------------
  // recommendations («Что ещё купить?»): вид спорта, мин. стаж, товар, причина
  // ---------------------------------------------------------------------------
  static const List<(String, int, String, String)> _recommendations = [
    ('volleyball', 0, 'water_bottle',
        'Пить воду нужно на каждой тренировке'),
    ('volleyball', 1, 'knee_brace',
        'При регулярных тренировках колени испытывают нагрузку — фиксатор её снижает'),
    ('volleyball', 2, 'mikasa_backpack',
        'Удобно носить мяч, форму и обувь на тренировки'),
    ('volleyball', 3, 'mikasa_ball',
        'С вашим стажем стоит тренироваться с профессиональным мячом'),
    ('running', 0, 'running_belt',
        'Телефон и ключи не будут мешать на пробежке'),
    ('running', 1, 'running_tights',
        'Компрессия помогает мышцам при увеличении дистанций'),
    ('running', 3, 'sport_watch',
        'Опытным бегунам важно контролировать пульс и темп'),
    ('football', 0, 'football_ball',
        'Собственный мяч — чтобы тренироваться в любое время'),
    ('football', 2, 'goalkeeper_gloves',
        'Пригодятся, если играете на воротах'),
    ('fitness', 0, 'water_bottle',
        'Пить воду нужно на каждой тренировке'),
    ('fitness', 1, 'dumbbells',
        'Для тренировок дома между походами в зал'),
    ('fitness', 2, 'kettlebell',
        'Гиря развивает силу и выносливость на продвинутом уровне'),
    ('basketball', 0, 'water_bottle',
        'Пить воду нужно на каждой тренировке'),
    ('swimming', 0, 'water_bottle',
        'После бассейна важно восполнить жидкость'),
    ('boxing', 0, 'mouth_guard',
        'Обязательная защита при спаррингах'),
    ('boxing', 1, 'water_bottle',
        'Интенсивные тренировки требуют много воды'),
    ('karate', 1, 'water_bottle',
        'Пить воду нужно на каждой тренировке'),
    ('yoga', 0, 'yoga_block',
        'Помогает правильно выполнять асаны на первых занятиях'),
    ('yoga', 1, 'water_bottle',
        'Пить воду нужно после каждой практики'),
  ];

  // ---------------------------------------------------------------------------
  // Запись в базу
  // ---------------------------------------------------------------------------

  /// Вид «Для всех видов спорта» и категория «Спортивное питание» —
  /// для товаров продавцов, которые не относятся к одному спорту.
  static Future<void> insertUniversal(DatabaseExecutor db) async {
    final List<Map<String, Object?>> sport = await db.query(
      DatabaseSchema.sports,
      where: 'name = ?',
      whereArgs: [Sport.universalName],
    );
    if (sport.isEmpty) {
      await db.insert(DatabaseSchema.sports, {
        'name': Sport.universalName,
        'description': 'Товар подходит для любого вида спорта',
      });
    }
    final List<Map<String, Object?>> category = await db.query(
      DatabaseSchema.categories,
      where: 'name = ?',
      whereArgs: [nutritionCategory],
    );
    if (category.isEmpty) {
      await db.insert(DatabaseSchema.categories, {'name': nutritionCategory});
    }
  }

  static const String nutritionCategory = 'Спортивное питание';

  /// Демо-отзывы: две трети — от подтверждённых покупателей.
  static Future<void> markVerifiedReviews(DatabaseExecutor db) => db.rawUpdate(
        'UPDATE ${DatabaseSchema.reviews} SET verified = 1 WHERE id % 3 != 0',
      );

  /// Спортивное питание магазина Sportlife — «для всех видов спорта».
  static const List<(String, String, int, String, String, int, String)> _nutrition = [
    (
      'Протеин сывороточный 900 г',
      'Сывороточный протеин со вкусом шоколада для восстановления после тренировок',
      15990,
      'Концентрат сывороточного белка (80%), какао-порошок, ароматизатор, '
          'подсластитель сукралоза. В порции 30 г — 24 г белка.',
      'sugar_free',
      25,
      'assets/images/products/whey_protein.jpg',
    ),
    (
      'Протеин растительный гороховый 750 г',
      'Белок из гороха и риса — для веганов и тех, кому не подходит молочный белок',
      13490,
      'Изолят горохового белка, рисовый белок, какао, стевия. '
          'В порции 30 г — 22 г белка.',
      'vegan,lactose_free,sugar_free',
      3,
      'assets/images/products/plant_protein.jpg',
    ),
    (
      'Изотоник порошок 500 г',
      'Напиток для долгих тренировок и забегов: вода, соли и быстрые углеводы',
      5490,
      'Декстроза, мальтодекстрин, цитрат натрия, хлорид калия, магний, '
          'витамин C, натуральный лимонный ароматизатор.',
      'vegan,lactose_free',
      40,
      'assets/images/products/isotonic.jpg',
    ),
  ];

  /// Демо-рекорды игры с мячом — таблица рекордов не пустая.
  static Future<void> insertGameScores(DatabaseExecutor db) async {
    const Map<String, List<int>> scores = {
      'football': [14, 9, 7, 5, 3],
      'volleyballLow': [11, 8, 6, 4],
      'volleyballHigh': [9, 7, 5],
      'basketball': [23, 17, 12, 8],
    };
    final List<String> emails = [
      for (final (_, _, email) in SeedReviews.reviewers) email,
    ];
    final List<Map<String, Object?>> users = await db.query(
      DatabaseSchema.users,
      columns: ['id'],
      where: 'email IN (${List.filled(emails.length, '?').join(', ')})',
      whereArgs: emails,
      orderBy: 'id',
    );
    if (users.isEmpty) return;
    for (final MapEntry<String, List<int>> mode in scores.entries) {
      for (int i = 0; i < mode.value.length; i++) {
        await db.insert(DatabaseSchema.gameScores, {
          'user_id': users[(i * 3 + mode.key.length) % users.length]['id'],
          'mode': mode.key,
          'score': mode.value[i],
          'created_at': DateTime(2026, 11, 1 + i).toIso8601String(),
        });
      }
    }
  }

  /// Демонстрационные номера документов о соответствии для спортпита
  /// (не настоящие документы). Отдельным шагом: колонка certificate
  /// появляется только в версии базы 20.
  static Future<void> applyDemoCertificates(DatabaseExecutor db) => db.rawUpdate(
        "UPDATE ${DatabaseSchema.products} SET certificate = 'ЕАЭС N KZ Д-DEMO.' || printf('%04d', id) "
        "WHERE certificate IS NULL AND category_id IN "
        "(SELECT id FROM ${DatabaseSchema.categories} WHERE name = ?)",
        [nutritionCategory],
      );

  static Future<void> insertNutrition(DatabaseExecutor db) async {
    Future<int?> idOf(String table, String column, String value) async {
      final List<Map<String, Object?>> rows = await db.query(table,
          columns: [table == DatabaseSchema.sellers ? 'user_id' : 'id'],
          where: '$column = ?', whereArgs: [value]);
      return rows.isEmpty ? null : rows.first.values.first as int?;
    }

    final int? sport = await idOf(DatabaseSchema.sports, 'name', Sport.universalName);
    final int? category =
        await idOf(DatabaseSchema.categories, 'name', nutritionCategory);
    if (sport == null || category == null) return;
    final int? seller = await idOf(DatabaseSchema.sellers, 'shop_name', 'Sportlife');
    for (final (name, description, price, composition, diet, stock, image)
        in _nutrition) {
      if (await idOf(DatabaseSchema.products, 'name', name) != null) continue;
      await db.insert(DatabaseSchema.products, {
        'name': name,
        'description': description,
        'price': price,
        'category_id': category,
        'sport_id': sport,
        'stock': stock,
        'brand': 'Sportlife',
        'image_url': image,
        'composition': composition,
        'diet': diet,
        'seller_id': seller,
        'rating': 4.7,
      });
    }
  }

  static Future<void> insertAll(DatabaseExecutor db) async {
    final Map<String, int> sportIds = {};
    for (final (key, name, description) in _sports) {
      sportIds[key] = await db.insert(DatabaseSchema.sports, {
        'name': name,
        'description': description,
      });
    }

    final Map<String, int> categoryIds = {};
    for (final (key, name) in _categories) {
      categoryIds[key] = await db.insert(DatabaseSchema.categories, {
        'name': name,
        'sport_id': null,
      });
    }

    final Map<String, int> productIds = {};
    for (final (key, name, description, price, category, sport, size, stock)
        in _products) {
      final (String, String, double)? details = _productDetails[key];
      productIds[key] = await db.insert(DatabaseSchema.products, {
        'name': name,
        'description': description,
        'price': price.toDouble(),
        'category_id': _id(categoryIds, category),
        'sport_id': _id(sportIds, sport),
        'size': size,
        'stock': stock,
        'image_url': '$_imagesFolder/$key.jpg',
        'brand': details?.$1,
        'material': details?.$2,
        'rating': details?.$3,
      });
    }

    await insertExtraProducts(db);

    for (final (sport, level, product, isMandatory) in _requirements) {
      await db.insert(DatabaseSchema.sportRequirements, {
        'sport_id': _id(sportIds, sport),
        'product_id': _id(productIds, product),
        'level': level.value,
        'is_mandatory': isMandatory ? 1 : 0,
      });
    }

    for (final (sport, minExperience, product, reason) in _recommendations) {
      await db.insert(DatabaseSchema.recommendations, {
        'sport_id': _id(sportIds, sport),
        'min_experience': minExperience,
        'product_id': _id(productIds, product),
        'reason': reason,
      });
    }

    await _insertUsersAndOrders(db, sportIds, productIds);
    await _insertExhibits(db, sportIds);
    await insertAthletes(db);
    await insertSellers(db);
    await applyVariants(db);
    await insertReviews(db);
    await markVerifiedReviews(db);
    await insertUniversal(db);
    await insertNutrition(db);
    await insertGameScores(db);
    await insertSportShop(db);
    await applyDemoCertificates(db);
  }

  /// Экспонаты «Зала славы» (экспозиция КНУС).
  static Future<void> _insertExhibits(
    DatabaseExecutor db,
    Map<String, int> sportIds,
  ) async {
    final Map<String, String> sportKeys = {
      for (final (key, name, _) in _sports) name: key,
    };
    final DateTime added = DateTime(2026, 11, 16);
    for (int i = 0; i < SeedExhibits.items.length; i++) {
      final (image, title, owner, year, sportLabel, catalogSport, story) =
          SeedExhibits.items[i];
      await db.insert(DatabaseSchema.exhibits, {
        'title': title,
        'athlete': owner,
        'sport_id':
            catalogSport == null ? null : _id(sportIds, sportKeys[catalogSport]!),
        'sport_label': sportLabel,
        'year': year,
        'story': story,
        'image_url': '${SeedExhibits.imagesFolder}/$image.jpg',
        'source': 'knus',
        // Порядок в списке — как в каталоге экспозиции: №1 первым.
        'created_at': added.subtract(Duration(minutes: i)).toIso8601String(),
      });
    }
  }

  /// Товары, добавленные позже основного каталога, и дополнительные фото
  /// товаров. Вызывается при создании базы (сразу после основного
  /// каталога — id совпадают с сервером) и при обновлении с версий 8–9.
  /// Виды спорта и категории ищутся по названию.
  static Future<void> insertExtraProducts(DatabaseExecutor db) async {
    Future<Map<String, int>> idsByName(String table) async => {
          for (final Map<String, Object?> row
              in await db.query(table, columns: ['id', 'name']))
            row['name']! as String: row['id']! as int,
        };
    final Map<String, int> sportsByName = await idsByName(DatabaseSchema.sports);
    final Map<String, int> categoriesByName =
        await idsByName(DatabaseSchema.categories);
    final Map<String, String> sportNames = {
      for (final (key, name, _) in _sports) key: name,
    };
    final Map<String, String> categoryNames = {
      for (final (key, name) in _categories) key: name,
    };
    for (final SeedProduct item in SeedProductsExtra.items) {
      await db.insert(DatabaseSchema.products, {
        'name': item.name,
        'description': item.description,
        'price': item.price.toDouble(),
        'category_id': categoriesByName[categoryNames[item.category]],
        'sport_id': sportsByName[sportNames[item.sport]],
        'size': item.sizes,
        'stock': item.stock,
        'image_url': SeedProductsExtra.path(item.key),
        'gallery': item.gallery.map(SeedProductsExtra.path).join('\n'),
        'brand': item.brand,
        'material': item.material,
        'rating': item.rating,
      });
    }
    await applyGalleries(db);
    // Детское кимоно — тоже у продавца кимоно (варианты в одном магазине).
    await db.update(
      DatabaseSchema.products,
      {'brand': SeedProductsExtra.kimonoSeller},
      where: 'image_url = ?',
      whereArgs: [SeedProductsExtra.path('karate_kimono')],
    );
  }

  /// Дополнительные фото товаров основного каталога (повторный вызов
  /// безопасен — фото просто перезаписываются).
  static Future<void> applyGalleries(DatabaseExecutor db) async {
    for (final MapEntry<String, List<String>> entry
        in SeedProductsExtra.galleries.entries) {
      await db.update(
        DatabaseSchema.products,
        {'gallery': entry.value.map(SeedProductsExtra.path).join('\n')},
        where: 'image_url = ?',
        whereArgs: [SeedProductsExtra.path(entry.key)],
      );
    }
  }

  /// Убирает из отзывов фото, которых больше нет в каталоге.
  static Future<void> removePhotos(DatabaseExecutor db) async {
    for (final String key in SeedProductsExtra.removedPhotos) {
      await db.update(
        DatabaseSchema.reviews,
        {'photos': null},
        where: 'photos = ?',
        whereArgs: [SeedProductsExtra.path(key)],
      );
    }
  }

  /// Варианты товаров (цвета и модели) с фото.
  static Future<void> applyVariants(DatabaseExecutor db) async {
    for (final MapEntry<String, List<(String, String)>> entry
        in SeedProductsExtra.variants.entries) {
      await db.update(
        DatabaseSchema.products,
        {
          'variants': jsonEncode([
            for (final (name, image) in entry.value)
              {'name': name, 'image': SeedProductsExtra.path(image)},
          ]),
        },
        where: 'image_url = ?',
        whereArgs: [SeedProductsExtra.path(entry.key)],
      );
    }
  }

  /// Демо-отзывы: по 3 от разных покупателей у каждого товара, у товаров
  /// с несколькими фото — с фото покупателя. Рейтинг товара и число
  /// отзывов пересчитываются по всем отзывам.
  static Future<void> insertReviews(DatabaseExecutor db) async {
    final List<int> reviewerIds = [];
    for (final (first, last, email) in SeedReviews.reviewers) {
      reviewerIds.add(await db.insert(DatabaseSchema.users, {
        'email': email,
        'password_hash': PasswordHasher.hash('Review123'),
        'role': UserRole.customer.value,
        'first_name': first,
        'last_name': last,
        'created_at': DateTime(2026, 9, 1).toIso8601String(),
      }));
    }
    final List<Map<String, Object?>> products = await db.rawQuery(
      'SELECT p.id, p.rating, p.gallery, c.name AS category '
      'FROM ${DatabaseSchema.products} p '
      'JOIN ${DatabaseSchema.categories} c ON c.id = p.category_id ORDER BY p.id',
    );
    for (int i = 0; i < products.length; i++) {
      final Map<String, Object?> product = products[i];
      final int productId = product['id']! as int;
      final List<int> ratings =
          SeedReviews.ratingsFor((product['rating'] as num?)?.toDouble() ?? 4.5);
      final List<String> texts = SeedReviews.texts[product['category']] ??
          SeedReviews.texts['Аксессуары']!;
      final List<String> gallery = ((product['gallery'] as String?) ?? '')
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();
      for (int k = 0; k < SeedReviews.perProduct; k++) {
        final int reviewer = reviewerIds[(i * 5 + k * 3) % reviewerIds.length];
        // Плохая оценка — с честным текстом про минус.
        final int rating = ratings[k];
        final String text = rating < 5
            ? texts.firstWhere((t) => t.contains('минус') || t.contains('маломерит') ||
                    t.contains('узковаты') || t.contains('жёсткие'),
                orElse: () => texts[(i + k) % texts.length])
            : texts[(i * 3 + k * 2) % texts.length];
        await db.insert(DatabaseSchema.reviews, {
          'user_id': reviewer,
          'product_id': productId,
          'rating': rating,
          'text': text,
          // Фото покупателя — у первого отзыва, если у товара есть фото.
          'photos': k == 0 && gallery.isNotEmpty
              ? gallery[i % gallery.length]
              : null,
          'created_at': DateTime(2026, 10, 1)
              .add(Duration(days: (i * 7 + k * 11) % 50, hours: k * 5))
              .toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await db.rawUpdate(
        'UPDATE ${DatabaseSchema.products} SET '
        'reviews_count = (SELECT COUNT(*) FROM ${DatabaseSchema.reviews} WHERE product_id = ?), '
        'rating = (SELECT ROUND(AVG(rating), 1) FROM ${DatabaseSchema.reviews} WHERE product_id = ?) '
        'WHERE id = ?',
        [productId, productId, productId],
      );
    }
  }

  /// Демо-продавцы и их магазины. Товары брендов «Budo Pro» и
  /// «Sportlife» — их; остальное продаёт сам магазин SPORT.
  ///   budo@sport.kz / Seller123 — магазин «Budo Pro» (кимоно)
  ///   sportlife@sport.kz / Seller123 — магазин «Sportlife»
  static Future<void> insertSellers(DatabaseExecutor db) async {
    final DateTime created = DateTime(2026, 11, 25);
    for (final (email, name, shop) in const [
      ('budo@sport.kz', 'Даурен', 'Budo Pro'),
      ('sportlife@sport.kz', 'Алия', 'Sportlife'),
    ]) {
      final int userId = await db.insert(DatabaseSchema.users, {
        'email': email,
        'password_hash': PasswordHasher.hash('Seller123'),
        'role': UserRole.customer.value,
        'first_name': name,
        'created_at': created.toIso8601String(),
      });
      await db.insert(DatabaseSchema.sellers, {
        'user_id': userId,
        'shop_name': shop,
        'created_at': created.toIso8601String(),
      });
      await db.update(
        DatabaseSchema.products,
        {'seller_id': userId},
        where: 'brand = ?',
        whereArgs: [shop],
      );
    }
  }

  /// Магазин SPORT — обычный продавец со своим кабинетом: ему
  /// принадлежат все товары без продавца, он сам ведёт их заказы.
  /// Администратор при этом только следит за порядком.
  static const String sportEmail = 'sport@sport.kz';

  static Future<void> insertSportShop(DatabaseExecutor db) async {
    final List<Map<String, Object?>> existing = await db.query(
      DatabaseSchema.users,
      columns: ['id'],
      where: 'email = ?',
      whereArgs: [sportEmail],
    );
    final DateTime created = DateTime(2026, 10, 6);
    final int userId = existing.isNotEmpty
        ? existing.first['id']! as int
        : await db.insert(DatabaseSchema.users, {
            'email': sportEmail,
            'password_hash': PasswordHasher.hash('Seller123'),
            'role': UserRole.customer.value,
            'first_name': 'SPORT',
            'created_at': created.toIso8601String(),
          });
    await db.insert(
      DatabaseSchema.sellers,
      {'user_id': userId, 'shop_name': 'SPORT', 'created_at': created.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.update(
      DatabaseSchema.products,
      {'seller_id': userId},
      where: 'seller_id IS NULL',
    );
  }

  /// Спортсмены Казахстана в «Зале славы». Вызывается и при создании
  /// базы, и при обновлении с версии 8 (виды спорта ищутся по названию).
  static Future<void> insertAthletes(DatabaseExecutor db) async {
    final Map<String, int> sportIdsByName = {
      for (final Map<String, Object?> row
          in await db.query(DatabaseSchema.sports, columns: ['id', 'name']))
        row['name']! as String: row['id']! as int,
    };
    // Позже экспонатов КНУС — в «Зале славы» спортсмены идут первыми.
    final DateTime added = DateTime(2026, 11, 22);
    for (int i = 0; i < SeedAthletes.items.length; i++) {
      final SeedAthlete athlete = SeedAthletes.items[i];
      final List<String> images = athlete.imagePaths;
      await db.insert(DatabaseSchema.exhibits, {
        'title': athlete.name,
        'athlete': athlete.headline,
        'sport_id': sportIdsByName[athlete.catalogSport],
        'sport_label': athlete.sport,
        'year': athlete.year,
        'story': athlete.story,
        'image_url': images.first,
        'gallery': images.skip(1).join('\n'),
        'source': 'kazakhstan',
        'created_at': added.subtract(Duration(minutes: i)).toIso8601String(),
      });
    }
  }

  static Future<void> _insertUsersAndOrders(
    DatabaseExecutor db,
    Map<String, int> sportIds,
    Map<String, int> productIds,
  ) async {
    // Администратор: admin@sport.kz / Admin123
    await db.insert(DatabaseSchema.users, {
      'email': 'admin@sport.kz',
      'password_hash': PasswordHasher.hash('Admin123'),
      'role': UserRole.admin.value,
      'first_name': 'Администратор',
      'last_name': null,
      'phone': null,
      'created_at': DateTime(2026, 1, 10).toIso8601String(),
    });

    // Покупатель из макетов: maria@mail.kz / Maria123
    final int mariaId = await db.insert(DatabaseSchema.users, {
      'email': 'maria@mail.kz',
      'password_hash': PasswordHasher.hash('Maria123'),
      'role': UserRole.customer.value,
      'first_name': 'Мария',
      'last_name': 'Габдулина',
      'phone': '+7 708 777 5555',
      'created_at': DateTime(2026, 2, 3).toIso8601String(),
    });
    await db.insert(DatabaseSchema.userSizes, {
      'user_id': mariaId,
      'height': 160,
      'weight': 60,
      'clothing_size': 'S',
      'shoe_size': 38,
      'experience_years': 6,
      'sport_id': _id(sportIds, 'volleyball'),
    });

    // Покупатель-новичок: ivan@mail.kz / Ivan1234
    final int ivanId = await db.insert(DatabaseSchema.users, {
      'email': 'ivan@mail.kz',
      'password_hash': PasswordHasher.hash('Ivan1234'),
      'role': UserRole.customer.value,
      'first_name': 'Иван',
      'last_name': 'Петров',
      'phone': '+7 701 123 4567',
      'created_at': DateTime(2026, 3, 15).toIso8601String(),
    });
    await db.insert(DatabaseSchema.userSizes, {
      'user_id': ivanId,
      'height': 180,
      'weight': 75,
      'clothing_size': 'L',
      'shoe_size': 43,
      'experience_years': 0,
      'sport_id': _id(sportIds, 'running'),
    });

    // Заказы Марии — номера как в макете «История заказов»
    const String mariaAddress = 'г. Астана, пр. Абая, д. 10, кв. 25';
    await _insertOrder(
      db,
      productIds: productIds,
      id: 1003,
      userId: mariaId,
      status: OrderStatus.newOrder,
      createdAt: DateTime(2026, 5, 20),
      customerName: 'Мария Габдулина',
      phone: '+7 708 777 5555',
      address: mariaAddress,
      deliveryMethod: DeliveryMethod.pickup,
      items: const [('water_bottle', 1)],
    );
    await _insertOrder(
      db,
      productIds: productIds,
      id: 1019,
      userId: mariaId,
      status: OrderStatus.inTransit,
      createdAt: DateTime(2026, 5, 16),
      customerName: 'Мария Габдулина',
      phone: '+7 708 777 5555',
      address: mariaAddress,
      deliveryMethod: DeliveryMethod.courier,
      items: const [('volleyball_uniform', 1), ('volleyball_knee_pads', 1)],
    );
    await _insertOrder(
      db,
      productIds: productIds,
      id: 1024,
      userId: mariaId,
      status: OrderStatus.delivered,
      createdAt: DateTime(2026, 5, 12),
      customerName: 'Мария Габдулина',
      phone: '+7 708 777 5555',
      address: mariaAddress,
      deliveryMethod: DeliveryMethod.courier,
      items: const [
        ('volleyball_knee_pads', 1),
        ('volleyball_shorts', 1),
        ('knee_brace', 1),
      ],
    );

    // Заказ Ивана
    await _insertOrder(
      db,
      productIds: productIds,
      id: 1010,
      userId: ivanId,
      status: OrderStatus.delivered,
      createdAt: DateTime(2026, 4, 2),
      customerName: 'Иван Петров',
      phone: '+7 701 123 4567',
      address: 'г. Астана, ул. Кенесары, д. 5',
      deliveryMethod: DeliveryMethod.courier,
      items: const [('running_shoes', 1), ('running_tshirt', 2)],
    );

    // Отзывы Ивана на полученные товары и вопросы покупателей.
    for (final (productKey, rating, text) in const [
      ('running_shoes', 5, 'Бегаю три раза в неделю — амортизация отличная, '
          'размер совпал с таблицей.'),
      ('running_tshirt', 4, 'Лёгкая и быстро сохнет. Снял бы балл за то, '
          'что немного свободна в плечах — берите на размер меньше.'),
    ]) {
      await db.insert(DatabaseSchema.reviews, {
        'user_id': ivanId,
        'product_id': _id(productIds, productKey),
        'rating': rating,
        'text': text,
        'created_at': DateTime(2026, 4, 20).toIso8601String(),
      });
      await db.update(
        DatabaseSchema.products,
        {'rating': rating.toDouble(), 'reviews_count': 1},
        where: 'id = ?',
        whereArgs: [_id(productIds, productKey)],
      );
    }
    await db.insert(DatabaseSchema.questions, {
      'product_id': _id(productIds, 'volleyball_shoes'),
      'user_id': ivanId,
      'text': 'Подойдут ли эти кроссовки для игры на улице?',
      'created_at': DateTime(2026, 5, 2).toIso8601String(),
      'answer': 'Подошва рассчитана на зал: на асфальте она быстро сотрётся. '
          'Для улицы лучше взять модель с более жёсткой резиной.',
      'answered_at': DateTime(2026, 5, 3).toIso8601String(),
    });
    await db.insert(DatabaseSchema.questions, {
      'product_id': _id(productIds, 'running_shoes'),
      'user_id': mariaId,
      'text': 'Маломерят ли эти кроссовки? Обычно ношу 38.',
      'created_at': DateTime(2026, 5, 18).toIso8601String(),
    });
  }

  /// Заказ + его позиции. Итог = товары + доставка.
  static Future<void> _insertOrder(
    DatabaseExecutor db, {
    required Map<String, int> productIds,
    required int id,
    required int userId,
    required OrderStatus status,
    required DateTime createdAt,
    required String customerName,
    required String phone,
    required String address,
    required DeliveryMethod deliveryMethod,
    required List<(String, int)> items,
  }) async {
    double itemsTotal = 0;
    final List<Map<String, Object?>> itemRows = [];
    for (final (productKey, quantity) in items) {
      final double price = _priceOf(productKey);
      itemsTotal += price * quantity;
      itemRows.add({
        'order_id': id,
        'product_id': _id(productIds, productKey),
        'quantity': quantity,
        'price': price,
      });
    }

    final double delivery = deliveryMethod == DeliveryMethod.courier
        ? AppConstants.courierDeliveryPrice
        : AppConstants.pickupDeliveryPrice;

    await db.insert(DatabaseSchema.orders, {
      'id': id,
      'user_id': userId,
      'status': status.value,
      'total_price': itemsTotal + delivery,
      'created_at': createdAt.toIso8601String(),
      'customer_name': customerName,
      'phone': phone,
      'delivery_address':
          deliveryMethod == DeliveryMethod.courier ? address : null,
      'delivery_method': deliveryMethod.value,
    });

    for (final Map<String, Object?> row in itemRows) {
      await db.insert(DatabaseSchema.orderItems, row);
    }
  }

  static double _priceOf(String productKey) {
    for (final product in _products) {
      if (product.$1 == productKey) return product.$4.toDouble();
    }
    throw StateError('В seed-данных нет товара "$productKey"');
  }

  static int _id(Map<String, int> ids, String key) {
    final int? id = ids[key];
    if (id == null) {
      throw StateError('В seed-данных нет ключа "$key"');
    }
    return id;
  }
}
