/// Параметры поиска и фильтрации каталога (экраны «Каталог» и «Фильтры»).
class ProductFilter {
  const ProductFilter({
    this.query = '',
    this.sportId,
    this.categoryId,
    this.size,
    this.minPrice,
    this.maxPrice,
    this.onlyAvailable = false,
    this.includeBlocked = false,
    this.sellerId,
  });

  /// Показывать и снятые с продажи (панели администратора и продавца).
  final bool includeBlocked;

  /// Только товары этого продавца (кабинет продавца).
  final int? sellerId;

  final String query;
  final int? sportId;
  final int? categoryId;
  final String? size;
  final double? minPrice;
  final double? maxPrice;
  final bool onlyAvailable;

  /// Количество активных фильтров (без поиска) — для подписи «Фильтры (2)».
  int get activeCount {
    final int filled = <Object?>[sportId, categoryId, size, minPrice, maxPrice]
        .where((value) => value != null)
        .length;
    return filled + (onlyAvailable ? 1 : 0);
  }

  bool get hasActiveFilters => activeCount > 0;

  ProductFilter withQuery(String newQuery) => copyWith(query: newQuery);

  /// Сброс всех фильтров с сохранением строки поиска.
  ProductFilter cleared() => ProductFilter(query: query);

  /// Флаги clear* нужны, чтобы убрать отдельный фильтр (поставить null).
  ProductFilter copyWith({
    String? query,
    int? sportId,
    int? categoryId,
    String? size,
    double? minPrice,
    double? maxPrice,
    bool? onlyAvailable,
    bool clearSport = false,
    bool clearCategory = false,
    bool clearSize = false,
    bool clearPrice = false,
  }) {
    return ProductFilter(
      query: query ?? this.query,
      sportId: clearSport ? null : (sportId ?? this.sportId),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      size: clearSize ? null : (size ?? this.size),
      minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
      onlyAvailable: onlyAvailable ?? this.onlyAvailable,
    );
  }
}
