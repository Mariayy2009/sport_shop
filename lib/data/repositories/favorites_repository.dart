import '../../models/product.dart';

/// Контракт работы с избранным пользователя.
abstract class FavoritesRepository {
  /// Избранные товары, сначала добавленные последними.
  Future<List<Product>> getFavorites(int userId);

  Future<void> add(int userId, int productId);

  Future<void> remove(int userId, int productId);
}
