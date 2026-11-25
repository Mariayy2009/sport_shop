import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../services/moderation/content_checker.dart';
import '../../database/database_schema.dart';
import '../../repositories/notification_repository.dart';

/// Автопроверка товара при сохранении: результат пишется в
/// products.moderation и products.risk.
///
/// * `pending` — явная запрещёнка у товара продавца: скрыт из каталога
///   до решения администратора;
/// * `flagged` — сомнительно: виден, но стоит в очереди администратора;
/// * `approved` — администратор посмотрел и разрешил;
/// * null — замечаний нет.
class ProductScreening {
  ProductScreening._();

  /// Проверить товар [productId]. [notify] — сообщить продавцу и
  /// администраторам, если товар скрыт.
  static Future<RiskReport> run(
    DatabaseExecutor db,
    int productId, {
    bool notify = true,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseSchema.products,
      where: 'id = ?',
      whereArgs: [productId],
    );
    if (rows.isEmpty) return const RiskReport([]);
    final Map<String, Object?> p = rows.first;
    // Обычная цена в категории — по остальным товарам (медиана).
    final List<Map<String, Object?>> prices = await db.query(
      DatabaseSchema.products,
      columns: ['price'],
      where: 'category_id = ? AND id != ?',
      whereArgs: [p['category_id'], productId],
      orderBy: 'price',
    );
    final double? median = prices.length < 3
        ? null
        : (prices[prices.length ~/ 2]['price']! as num).toDouble();
    final RiskReport report = ContentChecker.check(
      name: p['name']! as String,
      description: p['description'] as String?,
      composition: p['composition'] as String?,
      price: (p['price']! as num).toDouble(),
      medianPrice: median,
    );
    final int? sellerId = p['seller_id'] as int?;
    // Администратор уже разрешил — пока карточка не изменилась
    // (проверка та же), решение остаётся.
    final String risk = jsonEncode([for (final r in report.reasons) r.toJson()]);
    final bool sameAsApproved =
        p['moderation'] == 'approved' && p['risk'] == risk;
    final String? moderation = sameAsApproved
        ? 'approved'
        : report.hold && sellerId != null
            ? 'pending'
            : report.flag
                ? 'flagged'
                : null;
    await db.update(
      DatabaseSchema.products,
      {'moderation': moderation, 'risk': report.reasons.isEmpty ? null : risk},
      where: 'id = ?',
      whereArgs: [productId],
    );
    if (notify && moderation == 'pending' && p['moderation'] != 'pending') {
      await LocalNotificationRepository.push(
        db,
        userId: sellerId!,
        title: 'Товар отправлен на проверку',
        body: '«${p['name']}» появится в каталоге после проверки модератором. '
            'Замечание: ${report.reasons.first.label}',
        productId: productId,
      );
      final List<Map<String, Object?>> admins = await db.query(
        DatabaseSchema.users,
        columns: ['id'],
        where: 'role = ?',
        whereArgs: ['admin'],
      );
      for (final Map<String, Object?> admin in admins) {
        await LocalNotificationRepository.push(
          db,
          userId: admin['id']! as int,
          title: 'Подозрительный товар скрыт до проверки',
          body: '«${p['name']}»: ${report.reasons.map((r) => r.label).join(', ')}',
          productId: productId,
        );
      }
    }
    return report;
  }
}
