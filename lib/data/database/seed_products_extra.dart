/// Товары, добавленные позже основного каталога (фото предоставлены
/// автором проекта). Часть из них — варианты товаров того же продавца:
/// на странице товара они показываются в блоке «Ещё у продавца»,
/// как на маркетплейсах.
class SeedProduct {
  const SeedProduct({
    required this.key,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.sport,
    this.sizes,
    required this.stock,
    required this.brand,
    required this.material,
    required this.rating,
    this.gallery = const [],
  });

  /// Ключ = имя файла картинки в assets/images/products.
  final String key;
  final String name;
  final String description;
  final int price;
  final String category;
  final String sport;
  final String? sizes;
  final int stock;
  final String brand;
  final String material;
  final double rating;

  /// Дополнительные фото (ключи файлов) — листаются в карточке товара.
  final List<String> gallery;
}

class SeedProductsExtra {
  SeedProductsExtra._();

  static const String imagesFolder = 'assets/images/products';
  static const String _clothes = 'XS,S,M,L,XL';
  static const String _shoes = '36,37,38,39,40,41,42,43,44';

  /// Продавец кимоно: у него несколько видов кимоно.
  static const String kimonoSeller = 'Budo Pro';

  /// Новые товары. Порядок важен: id идут подряд после основного каталога
  /// и совпадают на телефоне и на сервере.
  static const List<SeedProduct> items = [
    SeedProduct(
      key: 'kimono_classic',
      name: 'Кимоно для карате классическое',
      description: 'Белое кимоно из плотного хлопка для ката и кумитэ. '
          'Чёрный пояс на фото — для примера, продаётся отдельно.',
      price: 21990,
      category: 'clothes',
      sport: 'karate',
      sizes: '140,150,160,170,180,190',
      stock: 8,
      brand: kimonoSeller,
      material: 'Хлопок 100%, 10 унций',
      rating: 4.8,
    ),
    SeedProduct(
      key: 'kimono_kyokushin',
      name: 'Кимоно киокушинкай',
      description: 'Кимоно для киокушин-карате с вышитыми иероглифами '
          '«Кёкусинкай» на груди и укороченными рукавами. Пояс в комплекте.',
      price: 18990,
      category: 'clothes',
      sport: 'karate',
      sizes: '130,140,150,160,170,180',
      stock: 10,
      brand: kimonoSeller,
      material: 'Хлопок 80%, полиэстер 20%',
      rating: 4.7,
    ),
    SeedProduct(
      key: 'nike_training_tee',
      name: 'Футболка тренировочная Nike Academy',
      description: 'Лёгкая футболка из ткани Dri-FIT для тренировок '
          'и игр: быстро отводит влагу.',
      price: 7990,
      category: 'clothes',
      sport: 'football',
      sizes: _clothes,
      stock: 20,
      brand: 'Nike',
      material: 'Полиэстер 100%',
      rating: 4.7,
    ),
    SeedProduct(
      key: 'running_shorts_2in1',
      name: 'Шорты беговые 2 в 1',
      description: 'Свободные шорты со встроенными компрессионными '
          'шортами: ничего не натирает на длинной дистанции.',
      price: 6490,
      category: 'clothes',
      sport: 'running',
      sizes: _clothes,
      stock: 15,
      brand: 'Sportlife',
      material: 'Полиэстер, эластан',
      rating: 4.6,
    ),
    SeedProduct(
      key: 'adidas_joggers',
      name: 'Штаны Adidas Essentials тёмно-синие',
      description: 'Спортивные джоггеры с манжетами и завязками на поясе.',
      price: 15990,
      category: 'clothes',
      sport: 'fitness',
      sizes: _clothes,
      stock: 12,
      brand: 'Adidas',
      material: 'Хлопок, полиэстер',
      rating: 4.7,
    ),
    SeedProduct(
      key: 'volleyball_uniform_women_1',
      name: 'Форма волейбольная женская',
      description: 'Майка и шорты с сублимационной печатью. Восемь '
          'расцветок — листайте фото. Номер наносится бесплатно.',
      price: 9990,
      category: 'clothes',
      sport: 'volleyball',
      sizes: 'XS,S,M,L',
      stock: 16,
      brand: 'Zhouka',
      material: 'Полиэстер 100%',
      rating: 4.6,
      gallery: [
        'volleyball_uniform_women_2',
        'volleyball_uniform_women_3',
        'volleyball_uniform_women_4',
        'volleyball_uniform_women_5',
        'volleyball_uniform_women_6',
        'volleyball_uniform_women_7',
        'volleyball_uniform_women_8',
      ],
    ),
    SeedProduct(
      key: 'fitness_set',
      name: 'Комплект для фитнеса: топ и леггинсы',
      description: 'Топ с плотной поддержкой и леггинсы с высокой '
          'посадкой. Не просвечивают при приседаниях.',
      price: 13990,
      category: 'clothes',
      sport: 'fitness',
      sizes: 'XS,S,M,L',
      stock: 9,
      brand: 'Sportlife',
      material: 'Полиамид, эластан',
      rating: 4.8,
      gallery: ['fitness_set_2'],
    ),
    SeedProduct(
      key: 'running_shoes_knit',
      name: 'Кроссовки беговые Knit',
      description: 'Лёгкие кроссовки с дышащим вязаным верхом '
          'и мягкой подошвой. Две расцветки — синяя и салатовая.',
      price: 17990,
      category: 'shoes',
      sport: 'running',
      sizes: _shoes,
      stock: 14,
      brand: 'Sportlife',
      material: 'Текстиль, пена EVA',
      rating: 4.5,
      gallery: ['running_shoes_knit_2'],
    ),
    SeedProduct(
      key: 'mikasa_v200w',
      name: 'Мяч волейбольный Mikasa V200W',
      description: 'Официальный мяч FIVB: на нём играют чемпионаты мира '
          'и Олимпийские игры.',
      price: 34990,
      category: 'equipment',
      sport: 'volleyball',
      stock: 5,
      brand: 'Mikasa',
      material: 'Микрофибра',
      rating: 4.9,
    ),
    SeedProduct(
      key: 'asics_knee_pads',
      name: 'Наколенники ASICS',
      description: 'Наколенники с толстой мягкой вставкой для приёма '
          'мяча в падении.',
      price: 4990,
      category: 'protection',
      sport: 'volleyball',
      sizes: 'S,M,L',
      stock: 18,
      brand: 'Asics',
      material: 'Нейлон, пена',
      rating: 4.7,
    ),
    SeedProduct(
      key: 'trionda_ball',
      name: 'Мяч Adidas Trionda',
      description: 'Мяч в дизайне официального мяча чемпионата мира '
          'по футболу 2026 года, размер 5.',
      price: 24990,
      category: 'equipment',
      sport: 'football',
      stock: 7,
      brand: 'Adidas',
      material: 'Полиуретан',
      rating: 4.9,
    ),
    SeedProduct(
      key: 'sport_backpack',
      name: 'Рюкзак спортивный Macron',
      description: 'Рюкзак с отдельным нижним отделением для обуви '
          'или мяча.',
      price: 11990,
      category: 'accessories',
      sport: 'football',
      stock: 10,
      brand: 'Macron',
      material: 'Полиэстер 600D',
      rating: 4.6,
    ),
    SeedProduct(
      key: 'swim_set',
      name: 'Набор для плавания: шапочка и очки',
      description: 'Силиконовая шапочка и очки с зеркальными линзами '
          'и защитой от запотевания.',
      price: 6990,
      category: 'accessories',
      sport: 'swimming',
      stock: 15,
      brand: 'Sportlife',
      material: 'Силикон, поликарбонат',
      rating: 4.6,
      gallery: ['swim_set_2'],
    ),
    SeedProduct(
      key: 'sport_bottle',
      name: 'Бутылка Sportlife 600 мл',
      description: 'Бутылка с клапаном-защёлкой: открывается одной рукой '
          'и не протекает в сумке.',
      price: 2490,
      category: 'accessories',
      sport: 'fitness',
      stock: 30,
      brand: 'Sportlife',
      material: 'Тритан',
      rating: 4.5,
    ),
    SeedProduct(
      key: 'arm_sleeves',
      name: 'Компрессионные рукава',
      description: 'Защищают руки от солнца (UPF 50) и охлаждают при беге. '
          'Семь цветов.',
      price: 1990,
      category: 'accessories',
      sport: 'running',
      sizes: 'S,M,L',
      stock: 40,
      brand: 'Sportlife',
      material: 'Нейлон, спандекс',
      rating: 4.3,
    ),
    SeedProduct(
      key: 'knee_sleeve',
      name: 'Наколенник компрессионный',
      description: 'Эластичный наколенник поддерживает сустав в зале '
          'и на пробежке.',
      price: 3490,
      category: 'protection',
      sport: 'fitness',
      sizes: 'S,M,L,XL',
      stock: 20,
      brand: 'Sportlife',
      material: 'Нейлон, латекс',
      rating: 4.4,
    ),
  ];

  /// Дополнительные фото для товаров основного каталога (ключ товара →
  /// ключи фото).
  static const Map<String, List<String>> galleries = {
    'football_ball': ['football_ball_2'],
    'kettlebell': ['kettlebell_set'],
    'yoga_mat': ['yoga_mat_purple'],
  };

  static String path(String key) => '$imagesFolder/$key.jpg';
}
