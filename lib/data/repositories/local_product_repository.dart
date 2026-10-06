import '../../models/category.dart';
import '../../models/product.dart';
import '../../models/product_filter.dart';
import '../../models/sport.dart';
import '../datasources/local/product_local_datasource.dart';
import 'product_repository.dart';

class LocalProductRepository implements ProductRepository {
  LocalProductRepository(this._dataSource);

  final ProductLocalDataSource _dataSource;

  @override
  Future<List<Product>> getProducts([
    ProductFilter filter = const ProductFilter(),
  ]) =>
      _dataSource.getProducts(filter);

  @override
  Future<Product?> getProductById(int id) => _dataSource.getProductById(id);

  @override
  Future<List<Sport>> getSports() => _dataSource.getSports();

  @override
  Future<List<ProductCategory>> getCategories() => _dataSource.getCategories();

  @override
  Future<Product> createProduct(Product product) =>
      _dataSource.insertProduct(product);

  @override
  Future<void> updateProduct(Product product) =>
      _dataSource.updateProduct(product);

  @override
  Future<void> deleteProduct(int id) => _dataSource.deleteProduct(id);
}
