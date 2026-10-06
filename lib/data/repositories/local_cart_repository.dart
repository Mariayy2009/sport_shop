import '../../models/cart_item.dart';
import '../datasources/local/cart_local_datasource.dart';
import 'cart_repository.dart';

class LocalCartRepository implements CartRepository {
  LocalCartRepository(this._dataSource);

  final CartLocalDataSource _dataSource;

  @override
  Future<List<CartItem>> getItems(int userId) => _dataSource.getItems(userId);

  @override
  Future<void> setQuantity({
    required int userId,
    required int productId,
    required String? size,
    required int quantity,
  }) =>
      _dataSource.setQuantity(
        userId: userId,
        productId: productId,
        size: size,
        quantity: quantity,
      );

  @override
  Future<void> clear(int userId) => _dataSource.clear(userId);
}
