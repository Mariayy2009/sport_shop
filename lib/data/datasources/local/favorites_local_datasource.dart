import 'package:sqflite/sqflite.dart';

import '../../../models/product.dart';
import '../../database/app_database.dart';
import '../../database/database_schema.dart';

/// SQL-запросы к таблице favorites.
class FavoritesLocalDataSource {
  FavoritesLocalDataSource(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<List<Product>> getFavorites(int userId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT p.*, c.name AS category_name, s.name AS sport_name '
      'FROM ${DatabaseSchema.favorites} f '
      'JOIN ${DatabaseSchema.products} p ON p.id = f.product_id '
      'JOIN ${DatabaseSchema.categories} c ON c.id = p.category_id '
      'JOIN ${DatabaseSchema.sports} s ON s.id = p.sport_id '
      'WHERE f.user_id = ? ORDER BY f.created_at DESC, p.name',
      [userId],
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<void> add(int userId, int productId) async {
    final Database db = await _appDatabase.database;
    await db.insert(
      DatabaseSchema.favorites,
      {
        'user_id': userId,
        'product_id': productId,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> remove(int userId, int productId) async {
    final Database db = await _appDatabase.database;
    await db.delete(
      DatabaseSchema.favorites,
      where: 'user_id = ? AND product_id = ?',
      whereArgs: [userId, productId],
    );
  }
}
