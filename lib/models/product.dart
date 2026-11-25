import 'dart:convert';

import 'item_options.dart';

/// Товар (таблица products).
class Product {
  const Product({
    this.id,
    required this.name,
    this.description,
    required this.price,
    required this.categoryId,
    required this.sportId,
    this.size,
    required this.stock,
    this.imageUrl,
    this.gallery = const [],
    this.variants = const [],
    this.brand,
    this.material,
    this.composition,
    this.diet = const [],
    this.rating,
    this.reviewsCount = 0,
    this.categoryName,
    this.sportName,
    this.sellerId,
    this.sellerName,
    this.isBlocked = false,
    this.blockReason,
  });

  /// Продавец (пользователь с магазином). null — продаёт сам магазин SPORT.
  final int? sellerId;

  /// Название магазина продавца — заполняется через JOIN.
  final String? sellerName;

  /// Снят с продажи администратором (запрещённый товар, мошенничество).
  /// Покупатели его не видят.
  final bool isBlocked;
  final String? blockReason;

  /// Кто продаёт — для карточки товара.
  String get sellerTitle => sellerName ?? 'SPORT';

  final int? id;
  final String name;
  final String? description;
  final double price;
  final int categoryId;
  final int sportId;

  /// Доступные размеры через запятую: «S,M,L» или «40,41,42».
  final String? size;
  final int stock;

  /// Путь к картинке: «assets/images/products/...» сейчас,
  /// «https://...» после переноса изображений в облако.
  final String? imageUrl;

  /// Дополнительные фото — листаются в карточке товара после [imageUrl].
  final List<String> gallery;

  /// Варианты (цвета, модели) — покупатель выбирает, какой положить
  /// в корзину.
  final List<ProductVariant> variants;

  ProductVariant? variantNamed(String? name) {
    for (final ProductVariant variant in variants) {
      if (variant.name == name) return variant;
    }
    return null;
  }

  /// Все фото товара: главное и дополнительные.
  List<String> get images => [
        if (imageUrl != null && imageUrl!.isNotEmpty) imageUrl!,
        ...gallery,
      ];

  /// Производитель: «Mizuno», «Adidas».
  final String? brand;

  /// Основной материал: «Полиэстер 100%».
  final String? material;

  /// Состав: для спортивного питания — ингредиенты, для одежды —
  /// ткань подробно. Заполняет продавец.
  final String? composition;

  /// Отметки спортпита: [DietTag.lactoseFree], [DietTag.vegan],
  /// [DietTag.sugarFree].
  final List<String> diet;

  /// Товар заканчивается — показываем «Осталось N шт.».
  static const int lowStock = 3;
  bool get isLowStock => stock > 0 && stock <= lowStock;

  /// Белок в порции из состава: «В порции 30 г — 24 г белка» → (30, 24).
  (int, int)? get proteinPortion {
    final RegExpMatch? m = RegExp(r'порции\s*(\d+)\s*г\s*[—-]\s*(\d+)\s*г\s*белка')
        .firstMatch(composition ?? '');
    return m == null ? null : (int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  /// Средняя оценка покупателей от 0 до 5.
  final double? rating;

  /// Сколько отзывов оставили покупатели.
  final int reviewsCount;


  // Заполняются через JOIN, в таблицу products не сохраняются.
  final String? categoryName;
  final String? sportName;

  bool get isAvailable => stock > 0;

  /// Нужно ли выбирать размер перед покупкой.
  bool get requiresSize => availableSizes.isNotEmpty;

  /// Подходящий размер из параметров пользователя или null.
  String? pickSize({String? clothingSize, int? shoeSize}) {
    final List<String> sizes = availableSizes;
    if (sizes.isEmpty) return null;
    if (clothingSize != null && sizes.contains(clothingSize)) {
      return clothingSize;
    }
    if (shoeSize != null && sizes.contains('$shoeSize')) return '$shoeSize';
    return null;
  }

  bool get isNetworkImage => imageUrl?.startsWith('http') ?? false;

  List<String> get availableSizes {
    final String raw = size?.trim() ?? '';
    if (raw.isEmpty) return const [];
    return raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  factory Product.fromMap(Map<String, Object?> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      // SQLite может вернуть REAL как int (например, 4990), поэтому num.
      price: (map['price'] as num).toDouble(),
      categoryId: map['category_id'] as int,
      sportId: map['sport_id'] as int,
      size: map['size'] as String?,
      stock: (map['stock'] as int?) ?? 0,
      imageUrl: map['image_url'] as String?,
      gallery: _gallery(map['gallery']),
      variants: _variants(map['variants']),
      brand: map['brand'] as String?,
      material: map['material'] as String?,
      composition: map['composition'] as String?,
      diet: [
        for (final String tag in ((map['diet'] as String?) ?? '').split(','))
          if (tag.trim().isNotEmpty) tag.trim(),
      ],
      rating: (map['rating'] as num?)?.toDouble(),
      reviewsCount: (map['reviews_count'] as int?) ?? 0,
      categoryName: map['category_name'] as String?,
      sportName: map['sport_name'] as String?,
      sellerId: map['seller_id'] as int?,
      sellerName: map['seller_name'] as String?,
      isBlocked: map['status'] == 'blocked',
      blockReason: map['block_reason'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category_id': categoryId,
      'sport_id': sportId,
      'size': size,
      'stock': stock,
      'image_url': imageUrl,
      'gallery': gallery.join('\n'),
      'variants': variants.isEmpty
          ? null
          : jsonEncode([for (final ProductVariant v in variants) v.toJson()]),
      'brand': brand,
      'material': material,
      'composition': composition,
      'diet': diet.isEmpty ? null : diet.join(','),
      'rating': rating,
      'seller_id': sellerId,
      'status': isBlocked ? 'blocked' : 'active',
      'block_reason': blockReason,
    };
  }

  /// Фото хранятся в базе одной строкой через перевод строки;
  /// сервер может прислать и список.
  static List<String> _gallery(Object? value) {
    final Iterable<Object?> items = value is List
        ? value
        : ((value as String?) ?? '').split('\n');
    return [
      for (final Object? item in items)
        if (item is String && item.trim().isNotEmpty) item.trim(),
    ];
  }

  static List<ProductVariant> _variants(Object? value) {
    Object? list = value;
    if (value is String && value.isNotEmpty) {
      try {
        list = jsonDecode(value);
      } on FormatException {
        return const [];
      }
    }
    if (list is! List) return const [];
    return [
      for (final Object? item in list)
        if (ProductVariant.fromJson(item) case final ProductVariant variant) variant,
    ];
  }

  factory Product.fromJson(Map<String, Object?> json) => Product.fromMap(json);

  Map<String, Object?> toJson() => toMap();

  Product copyWith({
    int? id,
    String? name,
    String? description,
    double? price,
    int? categoryId,
    int? sportId,
    String? size,
    int? stock,
    String? imageUrl,
    List<String>? gallery,
    String? brand,
    String? material,
    String? composition,
    double? rating,
    String? categoryName,
    String? sportName,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      categoryId: categoryId ?? this.categoryId,
      sportId: sportId ?? this.sportId,
      size: size ?? this.size,
      stock: stock ?? this.stock,
      imageUrl: imageUrl ?? this.imageUrl,
      gallery: gallery ?? this.gallery,
      variants: variants,
      brand: brand ?? this.brand,
      material: material ?? this.material,
      composition: composition ?? this.composition,
      diet: diet,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount,
      categoryName: categoryName ?? this.categoryName,
      sportName: sportName ?? this.sportName,
      sellerId: sellerId,
      sellerName: sellerName,
      isBlocked: isBlocked,
      blockReason: blockReason,
    );
  }

  @override
  bool operator ==(Object other) => other is Product && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Отметки спортивного питания — продавец ставит их в форме товара,
/// покупатель фильтрует каталог.
class DietTag {
  DietTag._();

  static const String lactoseFree = 'lactose_free';
  static const String vegan = 'vegan';
  static const String sugarFree = 'sugar_free';

  static const Map<String, String> labels = {
    lactoseFree: 'Без лактозы',
    vegan: 'Веган',
    sugarFree: 'Без сахара',
  };
}
