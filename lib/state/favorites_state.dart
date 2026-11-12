import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../data/repositories/favorites_repository.dart';
import '../models/product.dart';

/// Избранные товары текущего пользователя (таблица favorites).
class FavoritesState extends ChangeNotifier {
  FavoritesState(this._repository);

  final FavoritesRepository _repository;

  int? _userId;
  List<Product> _items = [];

  List<Product> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get count => _items.length;

  bool contains(int? productId) =>
      _items.any((product) => product.id == productId);

  /// Вызывается при входе / выходе пользователя.
  Future<void> setUser(int? userId) async {
    if (userId == _userId) return;
    _userId = userId;
    _items = [];
    notifyListeners();
    if (userId != null) await _reload();
  }

  /// Добавляет или убирает товар. Возвращает true, если товар теперь в избранном.
  Future<bool> toggle(Product product) async {
    final int? userId = _userId;
    if (userId == null) {
      throw const AppException('Войдите в аккаунт, чтобы сохранять избранное');
    }
    final bool wasFavorite = contains(product.id);
    if (wasFavorite) {
      await _repository.remove(userId, product.id!);
    } else {
      await _repository.add(userId, product.id!);
    }
    await _reload();
    return !wasFavorite;
  }

  Future<void> _reload() async {
    final int? userId = _userId;
    _items = userId == null ? [] : await _repository.getFavorites(userId);
    notifyListeners();
  }
}
