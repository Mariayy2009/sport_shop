import '../../core/errors/app_exception.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../models/product_filter.dart';
import '../../models/sport.dart';
import '../datasources/remote/shop_api_client.dart';
import 'product_repository.dart';

/// Каталог с сервера магазина (PostgreSQL). Этап 1 перехода:
/// только чтение. Изменение товаров через сервер появится вместе
/// со входом администратора на сервере (этап 2).
class ApiProductRepository implements ProductRepository {
  ApiProductRepository(this._api);

  final ShopApiClient _api;

  static const AppException _readOnly = AppException(
    'Каталог сейчас загружается с сервера, а изменять товары на сервере '
    'можно будет на следующем этапе. Чтобы отредактировать товар, '
    'переключитесь на данные «на телефоне» в профиле.',
  );

  @override
  Future<List<Product>> getProducts([
    ProductFilter filter = const ProductFilter(),
  ]) async {
    final List<Object?> rows = await _api.getJson('/products', {
      if (filter.query.trim().isNotEmpty) 'query': filter.query.trim(),
      if (filter.sportId != null) 'sport_id': '${filter.sportId}',
      if (filter.categoryId != null) 'category_id': '${filter.categoryId}',
      if (filter.size != null) 'size': filter.size!,
      if (filter.minPrice != null) 'min_price': '${filter.minPrice}',
      if (filter.maxPrice != null) 'max_price': '${filter.maxPrice}',
      if (filter.onlyAvailable) 'only_available': 'true',
    }) as List<Object?>? ?? const [];
    return [for (final Object? row in rows) Product.fromJson(row! as Map<String, Object?>)];
  }

  @override
  Future<Product?> getProductById(int id) async {
    final Object? row = await _api.getJson('/products/$id');
    return row == null ? null : Product.fromJson(row as Map<String, Object?>);
  }

  @override
  Future<List<Sport>> getSports() async {
    final List<Object?> rows =
        await _api.getJson('/sports') as List<Object?>? ?? const [];
    return [for (final Object? row in rows) Sport.fromJson(row! as Map<String, Object?>)];
  }

  @override
  Future<List<ProductCategory>> getCategories() async {
    final List<Object?> rows =
        await _api.getJson('/categories') as List<Object?>? ?? const [];
    return [
      for (final Object? row in rows)
        ProductCategory.fromJson(row! as Map<String, Object?>),
    ];
  }

  @override
  Future<Product> createProduct(Product product) async => throw _readOnly;

  @override
  Future<void> updateProduct(Product product) async => throw _readOnly;

  @override
  Future<void> deleteProduct(int id) async => throw _readOnly;
}
