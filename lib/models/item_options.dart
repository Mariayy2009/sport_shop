/// Выбор покупателя в позиции корзины и заказа: размер и вариант
/// (цвет или модель). Хранятся одной строкой в колонке size:
/// «M» — только размер, «M | Чёрный» — размер и вариант, «| Чёрный» —
/// только вариант. Так старые корзины и заказы читаются как раньше.
class ItemOptions {
  const ItemOptions({this.size, this.variant});

  final String? size;
  final String? variant;

  static const String _separator = ' | ';

  bool get isEmpty => size == null && variant == null;

  /// Строка для базы; null — ничего не выбрано.
  String? encode() {
    if (variant == null) return size;
    return '${size ?? ''}$_separator$variant'.trimLeft();
  }

  static ItemOptions decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const ItemOptions();
    if (!raw.contains('|')) return ItemOptions(size: raw.trim());
    final int at = raw.indexOf('|');
    final String size = raw.substring(0, at).trim();
    final String variant = raw.substring(at + 1).trim();
    return ItemOptions(
      size: size.isEmpty ? null : size,
      variant: variant.isEmpty ? null : variant,
    );
  }

  /// Для покупателя: «Размер M · Чёрный».
  String get label => [
        if (size != null) 'Размер $size',
        if (variant != null) variant!,
      ].join(' · ');
}

/// Вариант товара: цвет или модель со своим фото.
class ProductVariant {
  const ProductVariant(this.name, this.image);

  final String name;

  /// Путь к фото варианта.
  final String image;

  Map<String, Object?> toJson() => {'name': name, 'image': image};

  static ProductVariant? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? name = json['name'], image = json['image'];
    return name is String && image is String ? ProductVariant(name, image) : null;
  }
}
