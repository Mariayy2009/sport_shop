import 'package:sqflite/sqflite.dart';

import '../../models/product.dart';
import '../database/app_database.dart';
import '../database/database_schema.dart';
import 'notification_repository.dart';

/// Причины для предупреждения продавцу.
enum WarningReason {
  forbidden('Запрещённый товар'),
  fraud('Подозрение на мошенничество'),
  misleading('Неверное описание или фото'),
  price('Завышенная или ложная цена'),
  other('Другое');

  const WarningReason(this.label);

  final String label;

  static WarningReason fromLabel(String? label) => WarningReason.values
      .firstWhere((reason) => reason.label == label, orElse: () => other);
}

/// Предупреждение продавцу от администратора.
class SellerWarning {
  const SellerWarning({
    this.id,
    required this.sellerId,
    this.productId,
    this.productName,
    required this.reason,
    this.text,
    required this.createdAt,
    this.isRead = false,
  });

  final int? id;
  final int sellerId;
  final int? productId;

  /// Название товара — через JOIN (товар могли удалить).
  final String? productName;
  final WarningReason reason;

  /// Пояснение администратора.
  final String? text;
  final DateTime createdAt;
  final bool isRead;

  factory SellerWarning.fromMap(Map<String, Object?> map) => SellerWarning(
        id: map['id'] as int?,
        sellerId: map['seller_id'] as int,
        productId: map['product_id'] as int?,
        productName: map['product_name'] as String?,
        reason: WarningReason.fromLabel(map['reason'] as String?),
        text: map['text'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        isRead: map['is_read'] == 1,
      );
}

/// Состояние магазина продавца.
enum SellerStatus {
  active('active', 'Работает'),
  frozen('frozen', 'Заморожен'),
  deleted('deleted', 'Удалён');

  const SellerStatus(this.value, this.label);

  final String value;
  final String label;

  static SellerStatus fromValue(String? value) => SellerStatus.values
      .firstWhere((status) => status.value == value, orElse: () => active);
}

/// Апелляция продавца: просит объяснить заморозку или вернуть магазин.
class SellerAppeal {
  const SellerAppeal({
    required this.id,
    required this.sellerId,
    this.shopName,
    required this.text,
    required this.createdAt,
    required this.status,
    this.reply,
  });

  final int id;
  final int sellerId;
  final String? shopName;
  final String text;
  final DateTime createdAt;

  /// pending — ждёт решения, accepted — магазин восстановлен,
  /// rejected — отказано (с ответом администратора).
  final String status;
  final String? reply;

  bool get isPending => status == 'pending';

  String get statusLabel => switch (status) {
        'accepted' => 'Принята — магазин восстановлен',
        'rejected' => 'Отклонена',
        _ => 'На рассмотрении',
      };

  factory SellerAppeal.fromMap(Map<String, Object?> map) => SellerAppeal(
        id: map['id']! as int,
        sellerId: map['seller_id']! as int,
        shopName: map['shop_name'] as String?,
        text: map['text']! as String,
        createdAt: DateTime.parse(map['created_at']! as String),
        status: map['status']! as String,
        reply: map['reply'] as String?,
      );
}

/// Магазин продавца для администратора: сколько товаров и нарушений.
class SellerSummary {
  const SellerSummary({
    required this.userId,
    required this.shopName,
    required this.email,
    required this.products,
    required this.blocked,
    required this.warnings,
    this.status = SellerStatus.active,
    this.statusReason,
    this.pendingAppeals = 0,
  });

  final SellerStatus status;
  final String? statusReason;
  final int pendingAppeals;

  final int userId;
  final String shopName;
  final String email;
  final int products;
  final int blocked;
  final int warnings;
}

/// Модерация: администратор снимает товары с продажи и предупреждает
/// продавцов, продавец читает свои предупреждения.
abstract class ModerationRepository {
  /// Снять товар с продажи: покупатели его больше не видят. Продавцу
  /// приходит предупреждение с причиной.
  Future<void> blockProduct(Product product, WarningReason reason, {String? text});

  /// Вернуть товар в продажу.
  Future<void> unblockProduct(int productId);

  Future<void> warnSeller({
    required int sellerId,
    int? productId,
    required WarningReason reason,
    String? text,
  });

  Future<List<SellerWarning>> warningsFor(int sellerId);

  Future<int> unreadCount(int sellerId);

  Future<void> markRead(int sellerId);

  /// Все продавцы — для вкладки администратора «Продавцы».
  Future<List<SellerSummary>> sellers();

  /// Столько предупреждений подряд — и магазин замораживается сам.
  static const int autoFreezeWarnings = 3;

  Future<(SellerStatus, String?)> statusOf(int sellerId);

  /// Заморозить: товары скрыты из каталога, выставлять новые нельзя.
  Future<void> freezeSeller(int sellerId, String reason);

  /// Удалить магазин (крайняя мера). Данные не стираются: по апелляции
  /// администратор может магазин восстановить.
  Future<void> deleteSeller(int sellerId, String reason);

  /// Разморозить или восстановить магазин.
  Future<void> restoreSeller(int sellerId, {String? note});

  Future<void> submitAppeal(int sellerId, String text);

  Future<List<SellerAppeal>> appealsFor(int sellerId);

  /// Апелляции, ждущие решения, — для администратора.
  Future<List<SellerAppeal>> pendingAppeals();

  /// Решение по апелляции: принять (магазин снова работает) или отказать.
  Future<void> resolveAppeal(int appealId, {required bool accept, String? reply});
}

class LocalModerationRepository implements ModerationRepository {
  LocalModerationRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<void> blockProduct(Product product, WarningReason reason, {String? text}) async {
    final Database db = await _appDatabase.database;
    await db.update(
      DatabaseSchema.products,
      {'status': 'blocked', 'block_reason': reason.label},
      where: 'id = ?',
      whereArgs: [product.id],
    );
    // Покупатели, у которых товар в корзине, узнают сразу.
    final List<Map<String, Object?>> carts = await db.rawQuery(
      'SELECT DISTINCT user_id FROM ${DatabaseSchema.cartItems} WHERE product_id = ?',
      [product.id],
    );
    for (final Map<String, Object?> row in carts) {
      await LocalNotificationRepository.push(
        db,
        userId: row['user_id']! as int,
        title: 'Товар из корзины сняли с продажи',
        body: '«${product.name}» больше нельзя купить — уберите его из корзины',
        productId: product.id,
      );
    }
    if (product.sellerId != null) {
      await warnSeller(
        sellerId: product.sellerId!,
        productId: product.id,
        reason: reason,
        text: 'Товар снят с продажи.${text == null || text.isEmpty ? '' : ' $text'}',
      );
    }
  }

  @override
  Future<void> unblockProduct(int productId) async {
    final Database db = await _appDatabase.database;
    await db.update(
      DatabaseSchema.products,
      {'status': 'active', 'block_reason': null},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  @override
  Future<void> warnSeller({
    required int sellerId,
    int? productId,
    required WarningReason reason,
    String? text,
  }) async {
    final Database db = await _appDatabase.database;
    await db.insert(DatabaseSchema.sellerWarnings, {
      'seller_id': sellerId,
      'product_id': productId,
      'reason': reason.label,
      'text': text,
      'created_at': DateTime.now().toIso8601String(),
    });
    // Много нарушений подряд — магазин замораживается автоматически.
    // Считаются предупреждения после последней разморозки.
    final List<Map<String, Object?>> seller = await db.query(
      DatabaseSchema.sellers,
      columns: ['status', 'status_at'],
      where: 'user_id = ?',
      whereArgs: [sellerId],
    );
    if (seller.isEmpty || seller.first['status'] != SellerStatus.active.value) return;
    final int count = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseSchema.sellerWarnings} '
          'WHERE seller_id = ? AND created_at > ?',
          [sellerId, (seller.first['status_at'] as String?) ?? ''],
        )) ??
        0;
    if (count >= ModerationRepository.autoFreezeWarnings) {
      await freezeSeller(
        sellerId,
        'Автоматически: ${ModerationRepository.autoFreezeWarnings} предупреждения '
        'подряд. Исправьте нарушения и подайте апелляцию',
      );
    }
  }

  Future<void> _setStatus(
    DatabaseExecutor db,
    int sellerId,
    SellerStatus status,
    String? reason,
  ) =>
      db.update(
        DatabaseSchema.sellers,
        {
          'status': status.value,
          'status_reason': reason,
          'status_at': DateTime.now().toIso8601String(),
        },
        where: 'user_id = ?',
        whereArgs: [sellerId],
      );

  @override
  Future<(SellerStatus, String?)> statusOf(int sellerId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseSchema.sellers,
      columns: ['status', 'status_reason'],
      where: 'user_id = ?',
      whereArgs: [sellerId],
    );
    if (rows.isEmpty) return (SellerStatus.active, null);
    return (
      SellerStatus.fromValue(rows.first['status'] as String?),
      rows.first['status_reason'] as String?,
    );
  }

  @override
  Future<void> freezeSeller(int sellerId, String reason) async {
    final Database db = await _appDatabase.database;
    await db.transaction((txn) async {
      await _setStatus(txn, sellerId, SellerStatus.frozen, reason);
      await LocalNotificationRepository.push(
        txn,
        userId: sellerId,
        title: 'Магазин заморожен',
        body: '$reason. Товары скрыты из каталога. Если не согласны — '
            'подайте апелляцию в кабинете',
      );
    });
  }

  @override
  Future<void> deleteSeller(int sellerId, String reason) async {
    final Database db = await _appDatabase.database;
    await db.transaction((txn) async {
      await _setStatus(txn, sellerId, SellerStatus.deleted, reason);
      await LocalNotificationRepository.push(
        txn,
        userId: sellerId,
        title: 'Магазин удалён администратором',
        body: '$reason. Восстановить магазин можно только через апелляцию',
      );
    });
  }

  @override
  Future<void> restoreSeller(int sellerId, {String? note}) async {
    final Database db = await _appDatabase.database;
    await db.transaction((txn) async {
      await _setStatus(txn, sellerId, SellerStatus.active, null);
      await LocalNotificationRepository.push(
        txn,
        userId: sellerId,
        title: 'Магазин снова работает',
        body: note ?? 'Администратор восстановил ваш магазин, товары снова в каталоге',
      );
    });
  }

  @override
  Future<void> submitAppeal(int sellerId, String text) async {
    final Database db = await _appDatabase.database;
    await db.transaction((txn) async {
      await txn.insert(DatabaseSchema.sellerAppeals, {
        'seller_id': sellerId,
        'text': text,
        'created_at': DateTime.now().toIso8601String(),
      });
      // Администраторы узнают об апелляции сразу.
      final List<Map<String, Object?>> shop = await txn.query(
        DatabaseSchema.sellers,
        columns: ['shop_name'],
        where: 'user_id = ?',
        whereArgs: [sellerId],
      );
      final List<Map<String, Object?>> admins = await txn.query(
        DatabaseSchema.users,
        columns: ['id'],
        where: 'role = ?',
        whereArgs: ['admin'],
      );
      for (final Map<String, Object?> admin in admins) {
        await LocalNotificationRepository.push(
          txn,
          userId: admin['id']! as int,
          title: 'Апелляция от «${shop.isEmpty ? 'продавца' : shop.first['shop_name']}»',
          body: text,
        );
      }
    });
  }

  static const String _selectAppeals =
      'SELECT a.*, s.shop_name FROM ${DatabaseSchema.sellerAppeals} a '
      'LEFT JOIN ${DatabaseSchema.sellers} s ON s.user_id = a.seller_id';

  @override
  Future<List<SellerAppeal>> appealsFor(int sellerId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '$_selectAppeals WHERE a.seller_id = ? ORDER BY a.created_at DESC, a.id DESC',
      [sellerId],
    );
    return rows.map(SellerAppeal.fromMap).toList();
  }

  @override
  Future<List<SellerAppeal>> pendingAppeals() async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      "$_selectAppeals WHERE a.status = 'pending' ORDER BY a.created_at",
    );
    return rows.map(SellerAppeal.fromMap).toList();
  }

  @override
  Future<void> resolveAppeal(int appealId, {required bool accept, String? reply}) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseSchema.sellerAppeals,
      columns: ['seller_id'],
      where: 'id = ?',
      whereArgs: [appealId],
    );
    if (rows.isEmpty) return;
    final int sellerId = rows.first['seller_id']! as int;
    await db.update(
      DatabaseSchema.sellerAppeals,
      {
        'status': accept ? 'accepted' : 'rejected',
        'reply': reply,
        'resolved_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [appealId],
    );
    if (accept) {
      await restoreSeller(
        sellerId,
        note: 'Апелляция принята${reply == null || reply.isEmpty ? '' : ': $reply'}. '
            'Магазин снова работает',
      );
    } else {
      await LocalNotificationRepository.push(
        db,
        userId: sellerId,
        title: 'Апелляция отклонена',
        body: reply ?? 'Администратор не нашёл оснований снять ограничение',
      );
    }
  }

  @override
  Future<List<SellerWarning>> warningsFor(int sellerId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT w.*, p.name AS product_name '
      'FROM ${DatabaseSchema.sellerWarnings} w '
      'LEFT JOIN ${DatabaseSchema.products} p ON p.id = w.product_id '
      'WHERE w.seller_id = ? ORDER BY w.created_at DESC, w.id DESC',
      [sellerId],
    );
    return rows.map(SellerWarning.fromMap).toList();
  }

  @override
  Future<int> unreadCount(int sellerId) async {
    final Database db = await _appDatabase.database;
    return Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseSchema.sellerWarnings} '
          'WHERE seller_id = ? AND is_read = 0',
          [sellerId],
        )) ??
        0;
  }

  @override
  Future<void> markRead(int sellerId) async {
    final Database db = await _appDatabase.database;
    await db.update(
      DatabaseSchema.sellerWarnings,
      {'is_read': 1},
      where: 'seller_id = ?',
      whereArgs: [sellerId],
    );
  }

  @override
  Future<List<SellerSummary>> sellers() async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT s.user_id, s.shop_name, u.email, '
      '(SELECT COUNT(*) FROM ${DatabaseSchema.products} p WHERE p.seller_id = s.user_id) AS products, '
      "(SELECT COUNT(*) FROM ${DatabaseSchema.products} p WHERE p.seller_id = s.user_id AND p.status = 'blocked') AS blocked, "
      '(SELECT COUNT(*) FROM ${DatabaseSchema.sellerWarnings} w WHERE w.seller_id = s.user_id) AS warnings, '
      "(SELECT COUNT(*) FROM ${DatabaseSchema.sellerAppeals} a WHERE a.seller_id = s.user_id AND a.status = 'pending') AS appeals, "
      's.status, s.status_reason '
      'FROM ${DatabaseSchema.sellers} s JOIN ${DatabaseSchema.users} u ON u.id = s.user_id '
      'ORDER BY s.shop_name',
    );
    return [
      for (final Map<String, Object?> row in rows)
        SellerSummary(
          userId: row['user_id']! as int,
          shopName: row['shop_name']! as String,
          email: row['email']! as String,
          products: row['products']! as int,
          blocked: row['blocked']! as int,
          warnings: row['warnings']! as int,
          status: SellerStatus.fromValue(row['status'] as String?),
          statusReason: row['status_reason'] as String?,
          pendingAppeals: row['appeals']! as int,
        ),
    ];
  }
}
