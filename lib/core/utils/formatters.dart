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
}
