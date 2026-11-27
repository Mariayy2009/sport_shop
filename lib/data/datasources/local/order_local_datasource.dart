import 'package:sqflite/sqflite.dart';

import '../../../core/errors/app_exception.dart';
import '../../../models/enums.dart';
import '../../../models/order.dart';
import '../../../models/order_item.dart';
import '../../../models/product.dart';
import '../../database/app_database.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/order_repository.dart';
import 'product_screening.dart';
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

        await _warnLowStock(txn, item.productId);
        // Слишком частые покупки товара продавца — повод проверить.
        await ProductScreening.run(txn, item.productId);

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

  /// Заказы, в которых есть товары продавца [sellerId].
  Future<List<Order>> getOrdersForSeller(int sellerId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT DISTINCT o.* FROM ${DatabaseSchema.orders} o '
      'JOIN ${DatabaseSchema.orderItems} oi ON oi.order_id = o.id '
      'JOIN ${DatabaseSchema.products} p ON p.id = oi.product_id '
      'WHERE p.seller_id = ? ORDER BY o.created_at DESC, o.id DESC',
      [sellerId],
    );
    return _withItems(db, rows);
  }

  /// Продажи продавца: всё время, текущий месяц и лучшие товары.
  Future<SellerStats> sellerStats(int sellerId, {DateTime? now}) async {
    final Database db = await _appDatabase.database;
    final DateTime today = now ?? DateTime.now();
    final String monthStart = DateTime(today.year, today.month).toIso8601String();
    const String from =
        'FROM ${DatabaseSchema.orderItems} oi '
        'JOIN ${DatabaseSchema.orders} o ON o.id = oi.order_id '
        'JOIN ${DatabaseSchema.products} p ON p.id = oi.product_id '
        'WHERE p.seller_id = ?';
    final Map<String, Object?> all = (await db.rawQuery(
      'SELECT COUNT(DISTINCT o.id) AS orders, COALESCE(SUM(oi.quantity), 0) AS sold, '
      'COALESCE(SUM(oi.quantity * oi.price), 0) AS revenue $from',
      [sellerId],
    ))
        .first;
    final Map<String, Object?> month = (await db.rawQuery(
      'SELECT COALESCE(SUM(oi.quantity), 0) AS sold, '
      'COALESCE(SUM(oi.quantity * oi.price), 0) AS revenue $from AND o.created_at >= ?',
      [sellerId, monthStart],
    ))
        .first;
    final List<Map<String, Object?>> top = await db.rawQuery(
      'SELECT p.name, SUM(oi.quantity) AS sold, SUM(oi.quantity * oi.price) AS revenue '
      '$from GROUP BY p.id ORDER BY sold DESC, revenue DESC LIMIT 5',
      [sellerId],
    );
    return SellerStats(
      orders: all['orders']! as int,
      sold: (all['sold']! as num).toInt(),
      revenue: (all['revenue']! as num).toDouble(),
      monthSold: (month['sold']! as num).toInt(),
      monthRevenue: (month['revenue']! as num).toDouble(),
      topProduct: top.isEmpty ? null : top.first['name'] as String?,
      topSold: top.isEmpty ? 0 : (top.first['sold']! as num).toInt(),
      top: [
        for (final Map<String, Object?> row in top)
          (
            row['name']! as String,
            (row['sold']! as num).toInt(),
            (row['revenue']! as num).toDouble(),
          ),
      ],
    );
  }

  /// Продавцу: товар заканчивается — пора пополнить склад.
  static Future<void> _warnLowStock(Transaction txn, int productId) async {
    final List<Map<String, Object?>> rows = await txn.query(
      DatabaseSchema.products,
      columns: ['name', 'stock', 'seller_id'],
      where: 'id = ?',
      whereArgs: [productId],
    );
    if (rows.isEmpty) return;
    final int stock = rows.first['stock']! as int;
    final int? seller = rows.first['seller_id'] as int?;
    if (seller == null || stock > Product.lowStock) return;
    await LocalNotificationRepository.push(
      txn,
      userId: seller,
      title: stock == 0 ? 'Товар закончился' : 'Товар заканчивается',
      body: '«${rows.first['name']}»: ${stock == 0 ? 'на складе 0 шт.' : 'осталось $stock шт.'} '
          'Пополните остаток в кабинете',
      productId: productId,
    );
  }

  Future<void> updateTracking(int orderId, String? note) async {
    final Database db = await _appDatabase.database;
    await db.transaction((txn) async {
      await txn.update(
        DatabaseSchema.orders,
        {'tracking_note': note},
        where: 'id = ?',
        whereArgs: [orderId],
      );
      if (note != null && note.trim().isNotEmpty) {
        await _notifyBuyer(txn, orderId, 'Заказ №$orderId: где товар', note);
      }
    });
  }

  Future<void> updateStatus(int orderId, OrderStatus status) async {
    final Database db = await _appDatabase.database;
    await db.transaction((txn) async {
      await txn.update(
        DatabaseSchema.orders,
        {'status': status.value},
        where: 'id = ?',
        whereArgs: [orderId],
      );
      await _notifyBuyer(
        txn,
        orderId,
        'Заказ №$orderId: ${status.label.toLowerCase()}',
        switch (status) {
          OrderStatus.inTransit => 'Заказ отправлен и уже едет к вам',
          OrderStatus.delivered => 'Заказ доставлен. Оцените покупку — оставьте отзыв',
          _ => null,
        },
      );
    });
  }

  Future<void> _notifyBuyer(
    Transaction txn,
    int orderId,
    String title,
    String? body,
  ) async {
    final List<Map<String, Object?>> rows = await txn.query(
      DatabaseSchema.orders,
      columns: ['user_id'],
      where: 'id = ?',
      whereArgs: [orderId],
    );
    if (rows.isEmpty) return;
    await LocalNotificationRepository.push(
      txn,
      userId: rows.first['user_id']! as int,
      title: title,
      body: body,
      orderId: orderId,
    );
  }

  Future<List<Order>> _withItems(
    Database db,
    List<Map<String, Object?>> orderRows,
  ) async {
    final List<Order> orders = [];
    for (final Map<String, Object?> row in orderRows) {
      final List<Map<String, Object?>> itemRows = await db.rawQuery(
        'SELECT oi.*, p.name AS product_name, p.image_url AS product_image_url, '
        'p.seller_id AS product_seller_id, s.shop_name AS seller_name '
        'FROM ${DatabaseSchema.orderItems} oi '
        'JOIN ${DatabaseSchema.products} p ON p.id = oi.product_id '
        'LEFT JOIN ${DatabaseSchema.sellers} s ON s.user_id = p.seller_id '
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
