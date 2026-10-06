import 'package:sqflite/sqflite.dart';

import '../../../models/cart_item.dart';
import '../../../models/product.dart';
import '../../database/app_database.dart';
import '../../database/database_schema.dart';

/// SQL-запросы к таблице cart_items.
/// Корзина хранится в базе, поэтому не теряется после перезапуска.
class CartLocalDataSource {
  CartLocalDataSource(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<List<CartItem>> getItems(int userId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT p.*, c.name AS category_name, s.name AS sport_name, '
      'ci.quantity AS cart_quantity, ci.size AS cart_size '
      'FROM ${DatabaseSchema.cartItems} ci '
      'JOIN ${DatabaseSchema.products} p ON p.id = ci.product_id '
      'JOIN ${DatabaseSchema.categories} c ON c.id = p.category_id '
      'JOIN ${DatabaseSchema.sports} s ON s.id = p.sport_id '
      'WHERE ci.user_id = ? ORDER BY ci.id',
      [userId],
    );
    return rows
        .map((row) => CartItem(
              product: Product.fromMap(row),
              quantity: row['cart_quantity']! as int,
              selectedSize: row['cart_size'] as String?,
            ))
        .toList();
  }

  /// Устанавливает количество товара данного размера.
  /// 0 — удалить позицию.
  Future<void> setQuantity({
    required int userId,
    required int productId,
    required String? size,
    required int quantity,
  }) async {
    final Database db = await _appDatabase.database;
    // «size IS ?» корректно сравнивает и NULL (товар без размера).
    final List<Map<String, Object?>> existing = await db.query(
      DatabaseSchema.cartItems,
      columns: ['id'],
      where: 'user_id = ? AND product_id = ? AND size IS ?',
      whereArgs: [userId, productId, size],
      limit: 1,
    );

    if (quantity <= 0) {
      if (existing.isNotEmpty) {
        await db.delete(
          DatabaseSchema.cartItems,
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      }
      return;
    }

    if (existing.isEmpty) {
      await db.insert(DatabaseSchema.cartItems, {
        'user_id': userId,
        'product_id': productId,
        'size': size,
        'quantity': quantity,
      });
    } else {
      await db.update(
        DatabaseSchema.cartItems,
        {'quantity': quantity},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }

  Future<void> clear(int userId) async {
    final Database db = await _appDatabase.database;
    await db.delete(
      DatabaseSchema.cartItems,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }
}
