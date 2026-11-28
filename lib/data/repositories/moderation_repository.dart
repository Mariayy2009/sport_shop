import 'package:sqflite/sqflite.dart';

import '../../core/errors/app_exception.dart';
import '../../models/product.dart';
import '../../services/moderation/content_checker.dart';
import '../database/app_database.dart';
import '../datasources/local/product_screening.dart';
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

/// Данные продавца, обязательные для торговли (как у ИП/ТОО на
/// маркетплейсах), и согласие с правилами.
class SellerLegal {
  const SellerLegal({
    this.legalForm,
    this.iin,
    this.legalName,
    this.phone,
    this.address,
    this.agreedAt,
    this.rulesVersion,
  });

  /// «ИП», «ТОО» или «Самозанятый».
  final String? legalForm;

  /// ИИН (ИП, самозанятый) или БИН (ТОО).
  final String? iin;

  /// ФИО предпринимателя или название организации.
  final String? legalName;
  final String? phone;
  final String? address;
  final DateTime? agreedAt;
  final String? rulesVersion;

  static const List<String> forms = ['ИП', 'ТОО', 'Самозанятый'];

  bool get isBin => legalForm == 'ТОО';

  /// Можно торговать: всё заполнено и правила приняты.
  bool get complete =>
      [legalForm, iin, legalName, phone, address].every((v) => v != null && v.isNotEmpty) &&
      agreedAt != null;

  factory SellerLegal.fromMap(Map<String, Object?> map) => SellerLegal(
        legalForm: map['legal_form'] as String?,
        iin: map['iin'] as String?,
        legalName: map['legal_name'] as String?,
        phone: map['legal_phone'] as String?,
        address: map['legal_address'] as String?,
        agreedAt: DateTime.tryParse((map['agreed_at'] as String?) ?? ''),
        rulesVersion: map['rules_version'] as String?,
      );

  Map<String, Object?> toMap() => {
        'legal_form': legalForm,
        'iin': iin,
        'legal_name': legalName,
        'legal_phone': phone,
        'legal_address': address,
        'agreed_at': agreedAt?.toIso8601String(),
        'rules_version': rulesVersion,
      };
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
    this.since,
  });

  /// Магазин открыт.
  final DateTime? since;

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

  /// Очередь автопроверки: сначала скрытые, потом сомнительные.
  Future<List<Product>> reviewQueue();

  /// Администратор посмотрел — всё в порядке, товар в каталоге.
  Future<void> approveProduct(Product product);

  Future<SellerLegal> legalOf(int sellerId);

  /// Сохранить данные продавца и согласие с правилами.
  Future<void> saveLegal(int sellerId, SellerLegal legal);

  /// Покупатель открывает магазин: проверенные данные и название.
  Future<void> openShop(int userId, String shopName, SellerLegal legal);

  /// Материалы для правоохранительных органов: продавец, его данные,
  /// подозрительные товары с находками, заказы, предупреждения.
  Future<String> buildLawReport({required int sellerId, int? productId});

  /// Записать в журнал, что материалы подготовлены (кто и когда).
  Future<void> saveLawReport({
    required int sellerId,
    int? productId,
    int? adminId,
    required String text,
  });

  Future<int> lawReportsCount(int sellerId);

  /// Перепроверить весь каталог (например, после пополнения списка слов).
  /// Возвращает, сколько товаров попало в очередь.
  Future<int> rescanCatalog();
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
  Future<SellerLegal> legalOf(int sellerId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseSchema.sellers,
      where: 'user_id = ?',
      whereArgs: [sellerId],
    );
    return rows.isEmpty ? const SellerLegal() : SellerLegal.fromMap(rows.first);
  }

  @override
  Future<void> saveLegal(int sellerId, SellerLegal legal) async {
    final Database db = await _appDatabase.database;
    await db.update(
      DatabaseSchema.sellers,
      legal.toMap(),
      where: 'user_id = ?',
      whereArgs: [sellerId],
    );
  }

  @override
  Future<void> openShop(int userId, String shopName, SellerLegal legal) async {
    final Database db = await _appDatabase.database;
    // NOCASE в SQLite не понимает кириллицу — сравниваем сами.
    final List<Map<String, Object?>> shops = await db.query(
      DatabaseSchema.sellers,
      columns: ['user_id', 'shop_name'],
    );
    if (shops.any((row) => row['user_id'] == userId)) {
      throw const AppException('У вас уже есть магазин');
    }
    final String wanted = shopName.trim().toLowerCase();
    if (shops.any((row) => (row['shop_name']! as String).toLowerCase() == wanted)) {
      throw const AppException('Магазин с таким названием уже есть — выберите другое');
    }
    await db.insert(DatabaseSchema.sellers, {
      'user_id': userId,
      'shop_name': shopName.trim(),
      'created_at': DateTime.now().toIso8601String(),
      ...legal.toMap(),
    });
  }

  @override
  Future<String> buildLawReport({required int sellerId, int? productId}) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> seller = await db.rawQuery(
      'SELECT s.*, u.email, u.created_at AS user_created '
      'FROM ${DatabaseSchema.sellers} s JOIN ${DatabaseSchema.users} u ON u.id = s.user_id '
      'WHERE s.user_id = ?',
      [sellerId],
    );
    if (seller.isEmpty) throw const AppException('Продавец не найден');
    final Map<String, Object?> s = seller.first;
    final SellerLegal legal = SellerLegal.fromMap(s);
    String v(Object? value) =>
        value is String && value.isNotEmpty ? value : 'не указано';
    final List<Map<String, Object?>> products = await db.query(
      DatabaseSchema.products,
      where: productId == null
          ? "seller_id = ? AND (risk IS NOT NULL OR status = 'blocked')"
          : 'id = ?',
      whereArgs: [productId ?? sellerId],
    );
    final StringBuffer out = StringBuffer()
      ..writeln('МАТЕРИАЛЫ О ВОЗМОЖНОМ НАРУШЕНИИ НА ПЛОЩАДКЕ SPORT SHOP')
      ..writeln('Дата подготовки: ${DateTime.now().toIso8601String().substring(0, 16).replaceFirst('T', ' ')}')
      ..writeln()
      ..writeln('1. Продавец')
      ..writeln('Магазин: ${s['shop_name']}')
      ..writeln('Форма: ${v(legal.legalForm)}; ${legal.isBin ? 'БИН' : 'ИИН'}: ${v(legal.iin)}')
      ..writeln('ФИО / наименование: ${v(legal.legalName)}')
      ..writeln('Телефон: ${v(legal.phone)}; email: ${s['email']}')
      ..writeln('Юридический адрес: ${v(legal.address)}')
      ..writeln('Аккаунт создан: ${v(s['user_created'])}; правила приняты: '
          '${legal.agreedAt?.toIso8601String().substring(0, 10) ?? 'нет'} (редакция ${v(legal.rulesVersion)})')
      ..writeln('Статус магазина: ${v(s['status'])} ${s['status_reason'] == null ? '' : '(${s['status_reason']})'}')
      ..writeln()
      ..writeln('2. Товары и находки автоматической проверки');
    if (products.isEmpty) out.writeln('Подозрительных товаров нет.');
    for (final Map<String, Object?> p in products) {
      final int orders = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(DISTINCT order_id) FROM ${DatabaseSchema.orderItems} WHERE product_id = ?',
            [p['id']],
          )) ??
          0;
      out
        ..writeln('— «${p['name']}» (№${p['id']}), цена ${(p['price']! as num).round()} ₸, заказов: $orders, '
            'статус: ${p['status']}${p['block_reason'] == null ? '' : ' — ${p['block_reason']}'}')
        ..writeln('  Описание: ${v(p['description'])}')
        ..writeln('  Состав: ${v(p['composition'])}; материал: ${v(p['material'])}');
      if ((p['photo_text'] as String?)?.isNotEmpty ?? false) {
        out.writeln('  Текст на фото: ${p['photo_text']}');
      }
      final Product product = Product.fromMap(p);
      for (final RiskReason r in product.risk) {
        out.writeln('  Находка: ${r.label}: ${r.fragment}');
      }
    }
    final List<Map<String, Object?>> warnings = await db.query(
      DatabaseSchema.sellerWarnings,
      where: 'seller_id = ?',
      whereArgs: [sellerId],
      orderBy: 'created_at',
    );
    out
      ..writeln()
      ..writeln('3. Предупреждения продавцу: ${warnings.length}');
    for (final Map<String, Object?> w in warnings) {
      out.writeln('— ${(w['created_at']! as String).substring(0, 10)}: ${w['reason']}${w['text'] == null ? '' : '. ${w['text']}'}');
    }
    out
      ..writeln()
      ..writeln('Материалы подготовлены администрацией площадки для передачи в правоохранительные '
          'органы в порядке, установленном законодательством Республики Казахстан. Продавец '
          'принял Правила для продавцов, предусматривающие такую передачу.');
    return out.toString();
  }

  @override
  Future<void> saveLawReport({
    required int sellerId,
    int? productId,
    int? adminId,
    required String text,
  }) async {
    final Database db = await _appDatabase.database;
    await db.insert(DatabaseSchema.lawReports, {
      'seller_id': sellerId,
      'product_id': productId,
      'admin_id': adminId,
      'text': text,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<int> lawReportsCount(int sellerId) async {
    final Database db = await _appDatabase.database;
    return Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseSchema.lawReports} WHERE seller_id = ?',
          [sellerId],
        )) ??
        0;
  }

  @override
  Future<List<Product>> reviewQueue() async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT p.*, c.name AS category_name, s.name AS sport_name, '
      'sl.shop_name AS seller_name, sl.status AS seller_status '
      'FROM ${DatabaseSchema.products} p '
      'JOIN ${DatabaseSchema.categories} c ON c.id = p.category_id '
      'JOIN ${DatabaseSchema.sports} s ON s.id = p.sport_id '
      'LEFT JOIN ${DatabaseSchema.sellers} sl ON sl.user_id = p.seller_id '
      "WHERE p.moderation IN ('pending', 'flagged') AND p.status = 'active' "
      "ORDER BY p.moderation = 'pending' DESC, p.id DESC",
    );
    return rows.map(Product.fromMap).toList();
  }

  @override
  Future<void> approveProduct(Product product) async {
    final Database db = await _appDatabase.database;
    await db.update(
      DatabaseSchema.products,
      {'moderation': 'approved'},
      where: 'id = ?',
      whereArgs: [product.id],
    );
    if (product.sellerId != null && product.isPendingReview) {
      await LocalNotificationRepository.push(
        db,
        userId: product.sellerId!,
        title: 'Товар прошёл проверку',
        body: '«${product.name}» теперь в каталоге',
        productId: product.id,
      );
    }
  }

  @override
  Future<int> rescanCatalog() async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> ids = await db.query(
      DatabaseSchema.products,
      columns: ['id'],
      where: "status = 'active'",
    );
    int queued = 0;
    for (final Map<String, Object?> row in ids) {
      final RiskReport report =
          await ProductScreening.run(db, row['id']! as int);
      if (report.flag) queued++;
    }
    return queued;
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
      's.status, s.status_reason, s.created_at '
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
          since: DateTime.tryParse((row['created_at'] as String?) ?? ''),
        ),
    ];
  }
}
