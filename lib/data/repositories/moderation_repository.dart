import 'package:sqflite/sqflite.dart';

import '../../models/product.dart';
import '../database/app_database.dart';
import '../database/database_schema.dart';

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

/// Магазин продавца для администратора: сколько товаров и нарушений.
class SellerSummary {
  const SellerSummary({
    required this.userId,
    required this.shopName,
    required this.email,
    required this.products,
    required this.blocked,
    required this.warnings,
  });

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
      '(SELECT COUNT(*) FROM ${DatabaseSchema.sellerWarnings} w WHERE w.seller_id = s.user_id) AS warnings '
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
        ),
    ];
  }
}
