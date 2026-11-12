import 'package:flutter/painting.dart';

import 'product.dart';

/// Как вещь надевается на манекен в примерочной.
enum WearKind {
  top('Верх'),
  set('Форма'),
  kimono('Кимоно'),
  swimsuit('Купальник'),
  shorts('Шорты'),
  pants('Штаны'),
  shoes('Обувь'),
  knee('Защита коленей'),
  socks('Гетры');

  const WearKind(this.label);

  final String label;

  /// Вещь закрывает и верх, и низ — отдельный низ с ней не надевается.
  bool get coversLower =>
      this == WearKind.set || this == WearKind.kimono || this == WearKind.swimsuit;
}

/// Место на манекене. В каждом слоте одновременно одна вещь.
enum WearSlot {
  upper('Верх'),
  lower('Низ'),
  feet('Обувь'),
  extra('Защита');

  const WearSlot(this.label);

  final String label;
}

/// Надетая вещь: товар + выбранный цвет.
class WornItem {
  const WornItem({required this.product, required this.kind, required this.color});

  final Product product;
  final WearKind kind;
  final Color color;

  WornItem withColor(Color value) =>
      WornItem(product: product, kind: kind, color: value);
}

/// Правила примерочной: какие товары можно примерить и куда.
class Outfit {
  Outfit._();

  /// Цвета, в которые можно «перекрасить» вещь.
  static const List<Color> palette = [
    Color(0xFF10141C),
    Color(0xFFFFFFFF),
    Color(0xFFD7262B),
    Color(0xFF2F6BFF),
    Color(0xFF12B76A),
    Color(0xFFF5A524),
    Color(0xFF7A5AF8),
    Color(0xFFEE46BC),
  ];

  /// Тип вещи по категории и названию товара; null — товар не примеряется
  /// (мяч, бутылка, перчатки и т. п.).
  static WearKind? kindOf(Product product) {
    if (product.categoryName == 'Обувь') return WearKind.shoes;
    final String name = product.name.toLowerCase();
    if (name.contains('кимоно')) return WearKind.kimono;
    if (name.contains('купальник')) return WearKind.swimsuit;
    if (name.contains('форма')) return WearKind.set;
    if (name.contains('футболк')) return WearKind.top;
    if (name.contains('шорты')) return WearKind.shorts;
    if (name.contains('штаны') || name.contains('тайтс') || name.contains('леггинс')) {
      return WearKind.pants;
    }
    if (name.contains('наколенник') || name.contains('фиксатор')) {
      return WearKind.knee;
    }
    if (name.contains('гетры')) return WearKind.socks;
    return null;
  }

  static WearSlot slotOf(WearKind kind) => switch (kind) {
        WearKind.top ||
        WearKind.set ||
        WearKind.kimono ||
        WearKind.swimsuit =>
          WearSlot.upper,
        WearKind.shorts || WearKind.pants => WearSlot.lower,
        WearKind.shoes => WearSlot.feet,
        WearKind.knee || WearKind.socks => WearSlot.extra,
      };

  static Color defaultColor(WearKind kind) => switch (kind) {
        WearKind.kimono => palette[1],
        WearKind.set => palette[3],
        WearKind.top => palette[2],
        WearKind.swimsuit => palette[6],
        WearKind.shoes => palette[1],
        WearKind.knee => palette[0],
        WearKind.socks => palette[1],
        WearKind.shorts || WearKind.pants => palette[0],
      };
}
