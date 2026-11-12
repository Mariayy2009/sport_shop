import '../../models/product.dart';
import '../datasources/local/favorites_local_datasource.dart';
import 'favorites_repository.dart';

class LocalFavoritesRepository implements FavoritesRepository {
  LocalFavoritesRepository(this._dataSource);

  final FavoritesLocalDataSource _dataSource;

  @override
  Future<List<Product>> getFavorites(int userId) =>
      _dataSource.getFavorites(userId);

  @override
  Future<void> add(int userId, int productId) =>
      _dataSource.add(userId, productId);

  @override
  Future<void> remove(int userId, int productId) =>
      _dataSource.remove(userId, productId);
}
