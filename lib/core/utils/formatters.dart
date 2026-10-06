import 'package:intl/intl.dart';

import '../constants/app_strings.dart';

/// Форматирование значений для отображения в UI.
class Formatters {
  Formatters._();

  static final NumberFormat _priceFormat = NumberFormat('#,##0', 'ru');
  static final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');

  /// 4990 → «4 990 ₸»
  static String price(double value) =>
      '${_priceFormat.format(value)} ${AppStrings.currency}';

  /// → «12.05.2026»
  static String date(DateTime value) => _dateFormat.format(value);

  /// 24 → «#0024», 1024 → «#1024»
  static String orderNumber(int id) => '#${id.toString().padLeft(4, '0')}';

  /// Русское склонение: plural(3, 'товар', 'товара', 'товаров') → «товара».
  static String plural(int count, String one, String few, String many) {
    final int mod10 = count % 10;
    final int mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
    return many;
  }

  /// 3 → «3 товара»
  static String itemsCount(int count) =>
      '$count ${plural(count, 'товар', 'товара', 'товаров')}';

  /// 6 → «6 лет»
  static String years(int count) =>
      '$count ${plural(count, 'год', 'года', 'лет')}';
}
