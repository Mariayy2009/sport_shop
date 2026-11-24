import 'dart:convert';

/// Анкета покупателя для подбора: любимые цвета, позиция в своём виде
/// спорта и предпочитаемые материалы. Вид спорта, рост и размеры —
/// в профиле (UserSizes), здесь — вкусы и роль в игре.
class ShoppingPreferences {
  const ShoppingPreferences({
    this.colors = const {},
    this.position,
    this.materials = const {},
  });

  /// Ключи цветов из StyleCatalog.colors.
  final Set<String> colors;

  /// Ключ позиции из StyleCatalog.positions для вида спорта профиля.
  final String? position;

  /// Ключи материалов из StyleCatalog.materials.
  final Set<String> materials;

  bool get isEmpty => colors.isEmpty && position == null && materials.isEmpty;

  ShoppingPreferences copyWith({
    Set<String>? colors,
    String? position,
    bool clearPosition = false,
    Set<String>? materials,
  }) =>
      ShoppingPreferences(
        colors: colors ?? this.colors,
        position: clearPosition ? null : position ?? this.position,
        materials: materials ?? this.materials,
      );

  Map<String, Object?> toJson() => {
        'colors': colors.toList(),
        'position': position,
        'materials': materials.toList(),
      };

  factory ShoppingPreferences.fromJson(Map<String, Object?> json) {
    Set<String> strings(Object? value) =>
        value is List ? {for (final Object? item in value) if (item is String) item} : {};
    return ShoppingPreferences(
      colors: strings(json['colors']),
      position: json['position'] as String?,
      materials: strings(json['materials']),
    );
  }

  String encode() => jsonEncode(toJson());

  static ShoppingPreferences decode(String? text) {
    if (text == null || text.isEmpty) return const ShoppingPreferences();
    try {
      return ShoppingPreferences.fromJson(jsonDecode(text) as Map<String, Object?>);
    } on FormatException {
      return const ShoppingPreferences();
    }
  }
}
