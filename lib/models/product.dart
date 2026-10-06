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
    this.categoryName,
    this.sportName,
  });

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

  // Заполняются через JOIN, в таблицу products не сохраняются.
  final String? categoryName;
  final String? sportName;

  bool get isAvailable => stock > 0;

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
      categoryName: map['category_name'] as String?,
      sportName: map['sport_name'] as String?,
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
    };
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
      categoryName: categoryName ?? this.categoryName,
      sportName: sportName ?? this.sportName,
    );
  }

  @override
  bool operator ==(Object other) => other is Product && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
