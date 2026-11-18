import '../../models/category.dart';
import '../../models/product.dart';
import '../../models/product_filter.dart';
import '../../models/sport.dart';
import 'product_repository.dart';

/// Каталог, источник которого можно сменить без перезапуска:
/// SQLite на телефоне или сервер магазина с PostgreSQL.
///
/// Экраны и состояния работают с ProductRepository и не знают,
/// какой источник выбран сейчас.
class SwitchableProductRepository implements ProductRepository {
  SwitchableProductRepository(this._local);

  final ProductRepository _local;
  ProductRepository? _server;

  /// Каталог идёт с сервера.
  bool get usesServer => _server != null;

  void useServer(ProductRepository server) => _server = server;

  void useLocal() => _server = null;

  ProductRepository get _current => _server ?? _local;

  @override
  Future<List<Product>> getProducts([
    ProductFilter filter = const ProductFilter(),
  ]) =>
      _current.getProducts(filter);

  @override
  Future<Product?> getProductById(int id) => _current.getProductById(id);

  @override
  Future<List<Sport>> getSports() => _current.getSports();

  @override
  Future<List<ProductCategory>> getCategories() => _current.getCategories();

  @override
  Future<Product> createProduct(Product product) =>
      _current.createProduct(product);

  @override
  Future<void> updateProduct(Product product) =>
      _current.updateProduct(product);

  @override
  Future<void> deleteProduct(int id) => _current.deleteProduct(id);
}
