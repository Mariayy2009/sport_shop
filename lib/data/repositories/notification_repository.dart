import 'package:sqflite/sqflite.dart';

import '../../models/app_notification.dart';
import '../database/app_database.dart';
import '../database/database_schema.dart';

/// Уведомления пользователя (таблица notifications).
abstract class NotificationRepository {
  Future<List<AppNotification>> forUser(int userId);

  Future<int> unreadCount(int userId);

  Future<void> markAllRead(int userId);
}

class LocalNotificationRepository implements NotificationRepository {
  LocalNotificationRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  /// Записать уведомление — вызывается из других хранилищ в той же
  /// транзакции: ответ на вопрос, смена статуса заказа и т. д.
  static Future<void> push(
    DatabaseExecutor db, {
    required int userId,
    required String title,
    String? body,
    int? productId,
    int? orderId,
  }) =>
      db.insert(DatabaseSchema.notifications, {
        'user_id': userId,
        'title': title,
        'body': body,
        'product_id': productId,
        'order_id': orderId,
        'created_at': DateTime.now().toIso8601String(),
      });

  @override
  Future<List<AppNotification>> forUser(int userId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseSchema.notifications,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC, id DESC',
      limit: 100,
    );
    return rows.map(AppNotification.fromMap).toList();
  }

  @override
  Future<int> unreadCount(int userId) async {
    final Database db = await _appDatabase.database;
    return Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseSchema.notifications} '
          'WHERE user_id = ? AND is_read = 0',
          [userId],
        )) ??
        0;
  }

  @override
  Future<void> markAllRead(int userId) async {
    final Database db = await _appDatabase.database;
    await db.update(
      DatabaseSchema.notifications,
      {'is_read': 1},
      where: 'user_id = ? AND is_read = 0',
      whereArgs: [userId],
    );
  }
}
