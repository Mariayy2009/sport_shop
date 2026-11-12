import 'enums.dart';
import 'product.dart';
import 'sport.dart';

/// Позиция готового комплекта.
class KitItem {
  const KitItem({
    required this.product,
    required this.isMandatory,
    this.size,
  });

  final Product product;

  /// true — основа комплекта, false — полезное дополнение.
  final bool isMandatory;

  /// Размер, подобранный под пользователя (null — без размера или неизвестен).
  final String? size;
}

/// Готовый комплект экипировки для вида спорта и уровня подготовки.
class SportKit {
  const SportKit({
    required this.sport,
    required this.level,
    required this.items,
  });

  final Sport sport;
  final SportLevel level;
  final List<KitItem> items;

  List<KitItem> get mandatory =>
      items.where((item) => item.isMandatory).toList();

  List<KitItem> get extras => items.where((item) => !item.isMandatory).toList();

  /// Стоимость основы комплекта.
  double get basePrice => priceOf(mandatory);

  double get fullPrice => priceOf(items);

  static double priceOf(Iterable<KitItem> items) =>
      items.fold(0, (sum, item) => sum + item.product.price);
}
