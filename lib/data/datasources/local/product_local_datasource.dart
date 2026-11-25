import 'package:sqflite/sqflite.dart';

import '../../../models/category.dart';
import '../../../models/item_options.dart';
import '../../../models/product.dart';
import '../../../services/search/search_matcher.dart';
import '../../../models/product_filter.dart';
import '../../../models/sport.dart';
import '../../database/app_database.dart';
import '../../database/database_schema.dart';

/// SQL-запросы к таблицам products, categories, sports.
class ProductLocalDataSource {
  ProductLocalDataSource(this._appDatabase);

  final AppDatabase _appDatabase;

  /// Товар вместе с названиями категории и вида спорта (JOIN).
  static const String _selectProducts =
      'SELECT p.*, c.name AS category_name, s.name AS sport_name, '
      'sl.shop_name AS seller_name, sl.status AS seller_status '
      'FROM ${DatabaseSchema.products} p '
      'JOIN ${DatabaseSchema.categories} c ON c.id = p.category_id '
      'JOIN ${DatabaseSchema.sports} s ON s.id = p.sport_id '
      'LEFT JOIN ${DatabaseSchema.sellers} sl ON sl.user_id = p.seller_id';

  Future<List<Product>> getProducts(ProductFilter filter) async {
    final Database db = await _appDatabase.database;
    final List<String> conditions = [];
    final List<Object?> args = [];

    // Снятые с продажи товары видят только администратор и их продавец.
    // Товары замороженных и удалённых магазинов тоже скрыты.
    if (!filter.includeBlocked) {
      conditions.add("p.status = 'active'");
      conditions.add("(sl.status IS NULL OR sl.status = 'active')");
    }
    if (filter.sellerId != null) {
      conditions.add('p.seller_id = ?');
      args.add(filter.sellerId);
    }
    if (filter.sportId != null) {
      // Товары «для всех видов спорта» видны в каталоге каждого спорта.
      conditions.add(
        '(p.sport_id = ? OR p.sport_id IN '
        '(SELECT id FROM ${DatabaseSchema.sports} WHERE name = ?))',
      );
      args.addAll([filter.sportId, Sport.universalName]);
    }
    if (filter.categoryId != null) {
      conditions.add('p.category_id = ?');
      args.add(filter.categoryId);
    }
    if (filter.minPrice != null) {
      conditions.add('p.price >= ?');
      args.add(filter.minPrice);
    }
    if (filter.maxPrice != null) {
      conditions.add('p.price <= ?');
      args.add(filter.maxPrice);
    }
    if (filter.onlyAvailable) {
      conditions.add('p.stock > 0');
    }
    for (final String tag in filter.diet) {
      conditions.add("(',' || COALESCE(p.diet, '') || ',') LIKE ?");
      args.add('%,$tag,%');
    }
    if (filter.size != null) {
      // Размеры хранятся строкой «S,M,L» — ищем «,M,» внутри «,S,M,L,».
      conditions.add("(',' || REPLACE(p.size, ' ', '') || ',') LIKE ?");
      args.add('%,${filter.size},%');
    }

    final String where =
        conditions.isEmpty ? '' : ' WHERE ${conditions.join(' AND ')}';
    final List<Map<String, Object?>> rows =
        await db.rawQuery('$_selectProducts$where ORDER BY p.name', args);
    final List<Product> products = rows.map(Product.fromMap).toList();

    // Текстовый поиск делаем в Dart: LIKE в SQLite не умеет
    // сравнивать кириллицу без учёта регистра («Футболка» ≠ «футболка»).
    final String query = filter.query.trim();
    if (query.isEmpty) return products;
    // Без разницы языка: «adidas» = «Адидас», «найк» = «Nike».
    final SearchMatcher matcher = SearchMatcher(query);
    return products
        .where((product) => matcher.matches([
              product.name,
              product.brand,
              product.description,
              product.categoryName,
              product.sportName,
              product.sellerName,
              for (final ProductVariant variant in product.variants) variant.name,
            ]))
        .toList();
  }

  Future<Product?> getProductById(int id) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows =
        await db.rawQuery('$_selectProducts WHERE p.id = ? LIMIT 1', [id]);
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  Future<List<Sport>> getSports() async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows =
        await db.query(DatabaseSchema.sports, orderBy: 'id');
    return rows.map(Sport.fromMap).toList();
  }

  Future<List<ProductCategory>> getCategories() async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows =
        await db.query(DatabaseSchema.categories, orderBy: 'id');
    return rows.map(ProductCategory.fromMap).toList();
  }

  // ----- Для будущей административной части -----

  Future<Product> insertProduct(Product product) async {
    final Database db = await _appDatabase.database;
    final int id = await db.insert(
      DatabaseSchema.products,
      product.toMap()..remove('id'),
    );
    return product.copyWith(id: id);
  }

  Future<void> updateProduct(Product product) async {
    final Database db = await _appDatabase.database;
    await db.update(
      DatabaseSchema.products,
      product.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> deleteProduct(int id) async {
    final Database db = await _appDatabase.database;
    await db.delete(DatabaseSchema.products, where: 'id = ?', whereArgs: [id]);
  }
}
