import '../../models/category.dart';
import '../../models/product.dart';
import '../../models/product_filter.dart';
import '../../models/sport.dart';

/// Контракт работы с каталогом.
abstract class ProductRepository {
  Future<List<Product>> getProducts([ProductFilter filter = const ProductFilter()]);

  Future<Product?> getProductById(int id);

  Future<List<Sport>> getSports();

  Future<List<ProductCategory>> getCategories();

  // Для будущей административной части
  Future<Product> createProduct(Product product);

  Future<void> updateProduct(Product product);

  Future<void> deleteProduct(int id);
}
