import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../data/repositories/cart_repository.dart';
import '../models/cart_item.dart';
import '../models/item_options.dart';
import '../models/product.dart';

/// Состояние корзины текущего пользователя.
/// Ошибки (нет размера, не хватает на складе) — AppException с понятным текстом.
class CartState extends ChangeNotifier {
  CartState(this._repository);

  final CartRepository _repository;

  int? _userId;
  List<CartItem> _items = [];
  bool _isLoading = false;

  /// Позиции, с которых покупатель снял галочку: остаются в корзине,
  /// но не попадают в заказ.
  final Set<String> _skipped = {};

  static String _key(CartItem item) => '${item.product.id}|${item.selectedSize}';

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  bool get isLoading => _isLoading;

  int get totalQuantity => _items.fold(0, (sum, item) => sum + item.quantity);

  double get itemsTotal => _items.fold(0, (sum, item) => sum + item.total);

  /// Позицию можно купить сейчас (не снята с продажи, хватает на складе).
  bool isAvailable(CartItem item) => !unavailable.contains(item);

  /// Отмечена галочкой для заказа. Недоступные не отмечаются.
  bool isSelected(CartItem item) =>
      !_skipped.contains(_key(item)) && isAvailable(item);

  void toggle(CartItem item) {
    if (!_skipped.remove(_key(item))) _skipped.add(_key(item));
    notifyListeners();
  }

  bool get allSelected => _items.every((item) => isSelected(item) || !isAvailable(item));

  void selectAll(bool value) {
    _skipped.clear();
    if (!value) _skipped.addAll(_items.map(_key));
    notifyListeners();
  }

  /// Что пойдёт в заказ.
  List<CartItem> get selectedItems => [for (final CartItem i in _items) if (isSelected(i)) i];

  int get selectedQuantity => selectedItems.fold(0, (sum, item) => sum + item.quantity);

  double get selectedTotal => selectedItems.fold(0, (sum, item) => sum + item.total);

  /// После заказа убираем только купленное — остальное ждёт в корзине.
  Future<void> removeItems(List<CartItem> bought) async {
    final int userId = _requireUser();
    for (final CartItem item in bought) {
      await _repository.setQuantity(
        userId: userId,
        productId: item.product.id!,
        size: item.selectedSize,
        quantity: 0,
      );
      _skipped.remove(_key(item));
    }
    await _reload();
  }

  Set<int> get productIds => {for (final CartItem item in _items) item.product.id!};

  bool containsProduct(int? productId) =>
      _items.any((item) => item.product.id == productId);

  /// В корзине именно этот вариант (цвет, модель) товара.
  bool containsVariant(int? productId, String? variant) => _items.any((item) =>
      item.product.id == productId &&
      (variant == null || ItemOptions.decode(item.selectedSize).variant == variant));

  /// Вызывается при входе / выходе пользователя.
  Future<void> setUser(int? userId) async {
    if (userId == _userId) return;
    _userId = userId;
    _items = [];
    _skipped.clear();
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
              item.product.isPendingReview ||
              item.product.stock < item.quantity)
            item,
      ];

  Future<void> _reload() async {
    final int? userId = _userId;
    _items = userId == null ? [] : await _repository.getItems(userId);
    notifyListeners();
  }
}
