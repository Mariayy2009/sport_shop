import 'package:sqflite/sqflite.dart';

import '../../../core/errors/app_exception.dart';
import '../../../models/enums.dart';
import '../../../models/order.dart';
import '../../../models/order_item.dart';
import '../../database/app_database.dart';
import '../../database/database_schema.dart';

/// SQL-запросы к таблицам orders и order_items.
class OrderLocalDataSource {
  OrderLocalDataSource(this._appDatabase);

  final AppDatabase _appDatabase;

  /// Сохраняет заказ, его позиции и уменьшает остатки на складе.
  /// Всё в одной транзакции: если товара не хватит, ничего не сохранится.
  Future<Order> createOrder(Order order) async {
    final Database db = await _appDatabase.database;
    return db.transaction((txn) async {
      final int orderId = await txn.insert(
        DatabaseSchema.orders,
        order.toMap()..remove('id'),
      );

      final List<OrderItem> savedItems = [];
      for (final OrderItem item in order.items) {
        final int updatedRows = await txn.rawUpdate(
          'UPDATE ${DatabaseSchema.products} SET stock = stock - ? '
          'WHERE id = ? AND stock >= ?',
          [item.quantity, item.productId, item.quantity],
        );
        if (updatedRows == 0) {
          final String name = item.productName ?? 'товар №${item.productId}';
          throw AppException('Недостаточно товара на складе: «$name»');
        }

        final OrderItem itemWithOrder = item.copyWith(orderId: orderId);
        final int itemId = await txn.insert(
          DatabaseSchema.orderItems,
          itemWithOrder.toMap()..remove('id'),
        );
        savedItems.add(itemWithOrder.copyWith(id: itemId));
      }

      return order.copyWith(id: orderId, items: savedItems);
    });
  }

  Future<List<Order>> getOrdersByUser(int userId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseSchema.orders,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC, id DESC',
    );
    return _withItems(db, rows);
  }

  Future<Order?> getOrderById(int orderId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseSchema.orders,
      where: 'id = ?',
      whereArgs: [orderId],
      limit: 1,
    );
    final List<Order> orders = await _withItems(db, rows);
    return orders.isEmpty ? null : orders.first;
  }

  /// Все заказы — для будущей административной части.
  Future<List<Order>> getAllOrders() async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseSchema.orders,
      orderBy: 'created_at DESC, id DESC',
    );
    return _withItems(db, rows);
  }

  Future<void> updateStatus(int orderId, OrderStatus status) async {
    final Database db = await _appDatabase.database;
    await db.update(
      DatabaseSchema.orders,
      {'status': status.value},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<List<Order>> _withItems(
    Database db,
    List<Map<String, Object?>> orderRows,
  ) async {
    final List<Order> orders = [];
    for (final Map<String, Object?> row in orderRows) {
      final List<Map<String, Object?>> itemRows = await db.rawQuery(
        'SELECT oi.*, p.name AS product_name, p.image_url AS product_image_url '
        'FROM ${DatabaseSchema.orderItems} oi '
        'JOIN ${DatabaseSchema.products} p ON p.id = oi.product_id '
        'WHERE oi.order_id = ? ORDER BY oi.id',
        [row['id']],
      );
      orders.add(
        Order.fromMap(row, items: itemRows.map(OrderItem.fromMap).toList()),
      );
    }
    return orders;
  }
}
