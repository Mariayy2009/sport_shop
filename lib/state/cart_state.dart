import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../data/repositories/cart_repository.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

/// Состояние корзины текущего пользователя.
/// Ошибки (нет размера, не хватает на складе) — AppException с понятным текстом.
class CartState extends ChangeNotifier {
  CartState(this._repository);

  final CartRepository _repository;

  int? _userId;
  List<CartItem> _items = [];
  bool _isLoading = false;

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  bool get isLoading => _isLoading;

  int get totalQuantity => _items.fold(0, (sum, item) => sum + item.quantity);

  double get itemsTotal => _items.fold(0, (sum, item) => sum + item.total);

  Set<int> get productIds => {for (final CartItem item in _items) item.product.id!};

  bool containsProduct(int? productId) =>
      _items.any((item) => item.product.id == productId);

  /// Вызывается при входе / выходе пользователя.
  Future<void> setUser(int? userId) async {
    if (userId == _userId) return;
    _userId = userId;
    _items = [];
    notifyListeners();
    if (userId == null) return;

    _isLoading = true;
    notifyListeners();
    try {
      await _reload();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> add(Product product, {String? size, int quantity = 1}) async {
    final int userId = _requireUser();
    if (!product.isAvailable) {
      throw AppException('Товар «${product.name}» закончился');
    }
    if (product.requiresSize && size == null) {
      throw const AppException('Выберите размер');
    }
    final CartItem? existing = _find(product.id!, size);
    final int newQuantity = (existing?.quantity ?? 0) + quantity;
    if (newQuantity > product.stock) {
      throw AppException(
        'На складе только ${product.stock} шт. товара «${product.name}»',
      );
    }
    await _repository.setQuantity(
      userId: userId,
      productId: product.id!,
      size: size,
      quantity: newQuantity,
    );
    await _reload();
  }

  Future<void> updateQuantity(CartItem item, int quantity) async {
    final int userId = _requireUser();
    if (quantity > item.product.stock) {
      throw AppException('На складе только ${item.product.stock} шт.');
    }
    await _repository.setQuantity(
      userId: userId,
      productId: item.product.id!,
      size: item.selectedSize,
      quantity: quantity < 0 ? 0 : quantity,
    );
    await _reload();
  }

  Future<void> remove(CartItem item) => updateQuantity(item, 0);

  Future<void> clear() async {
    final int userId = _requireUser();
    await _repository.clear(userId);
    await _reload();
  }

  CartItem? _find(int productId, String? size) {
    for (final CartItem item in _items) {
      if (item.product.id == productId && item.selectedSize == size) {
        return item;
      }
    }
    return null;
  }

  int _requireUser() {
    final int? userId = _userId;
    if (userId == null) {
      throw const AppException('Войдите в аккаунт, чтобы пользоваться корзиной');
    }
    return userId;
  }

  /// Перечитать корзину: товар могли снять с продажи или раскупить.
  Future<void> refresh() => _reload();

  /// Позиции, которые нельзя купить: сняты с продажи или не хватает
  /// на складе.
  List<CartItem> get unavailable => [
        for (final CartItem item in _items)
          if (item.product.isBlocked ||
              item.product.sellerInactive ||
              item.product.stock < item.quantity)
            item,
      ];

  Future<void> _reload() async {
    final int? userId = _userId;
    _items = userId == null ? [] : await _repository.getItems(userId);
    notifyListeners();
  }
}
