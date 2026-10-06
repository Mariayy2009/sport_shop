import '../../models/cart_item.dart';

/// Контракт работы с корзиной пользователя.
abstract class CartRepository {
  Future<List<CartItem>> getItems(int userId);

  /// Количество позиции (товар + размер); 0 — удалить.
  Future<void> setQuantity({
    required int userId,
    required int productId,
    required String? size,
    required int quantity,
  });

  Future<void> clear(int userId);
}
