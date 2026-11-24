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
    this.brand,
    this.material,
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

  /// Все фото товара: главное и дополнительные.
  List<String> get images => [
        if (imageUrl != null && imageUrl!.isNotEmpty) imageUrl!,
        ...gallery,
      ];

  /// Производитель: «Mizuno», «Adidas».
  final String? brand;

  /// Основной материал: «Полиэстер 100%».
  final String? material;

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
      brand: map['brand'] as String?,
      material: map['material'] as String?,
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
      'brand': brand,
      'material': material,
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
      brand: brand ?? this.brand,
      material: material ?? this.material,
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
