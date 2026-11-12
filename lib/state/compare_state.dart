import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../models/product.dart';

/// Список сравнения. Живёт в памяти: это рабочий инструмент выбора,
/// а не данные пользователя, поэтому в базу не сохраняется.
class CompareState extends ChangeNotifier {
  static const int maxItems = 4;

  final List<Product> _items = [];

  List<Product> get items => List.unmodifiable(_items);
  int get count => _items.length;
  bool get isEmpty => _items.isEmpty;

  bool contains(int? productId) =>
      _items.any((product) => product.id == productId);

  /// Добавляет или убирает товар. Возвращает true, если товар теперь в списке.
  bool toggle(Product product) {
    if (contains(product.id)) {
      remove(product);
      return false;
    }
    if (_items.length >= maxItems) {
      throw const AppException(
        'Сравнить можно до $maxItems товаров. Уберите один из списка',
      );
    }
    _items.add(product);
    notifyListeners();
    return true;
  }

  void remove(Product product) {
    _items.removeWhere((item) => item.id == product.id);
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}
