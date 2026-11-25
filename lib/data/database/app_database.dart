import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'database_schema.dart';
import 'seed_data.dart';

/// Единая точка доступа к SQLite.
///
/// Используется ТОЛЬКО слоем data (LocalDataSource-классы, этап 5).
/// Экраны с базой напрямую не работают.
class AppDatabase {
  AppDatabase._(this._customPath);

  /// Основной экземпляр приложения.
  static final AppDatabase instance = AppDatabase._(null);

  /// Отдельная база по указанному пути (для тестов).
  factory AppDatabase.withPath(String path) => AppDatabase._(path);

  final String? _customPath;
  Future<Database>? _opening;

  /// Открытая база. При первом обращении создаются таблицы и демо-данные.
  /// Future кешируется, чтобы при одновременных вызовах база не открылась дважды.
  Future<Database> get database => _opening ??= _open();

  Future<String> _resolvePath() async {
    return _customPath ??
        join(await getDatabasesPath(), DatabaseSchema.databaseName);
  }

  Future<Database> _open() async {
    return openDatabase(
      await _resolvePath(),
      version: DatabaseSchema.version,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// В SQLite внешние ключи по умолчанию выключены — включаем.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    for (final String statement in DatabaseSchema.createStatements) {
      await db.execute(statement);
    }
    await SeedData.insertAll(db);
  }

  /// Обновление схемы. С v8 — пошаговая миграция без потери данных
  /// (корзина, заказы, избранное сохраняются). Более старые базы
  /// учебной версии пересоздаются с демо-данными.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion >= 8) {
      if (oldVersion < 9) {
        await db.execute(
          'ALTER TABLE ${DatabaseSchema.exhibits} ADD COLUMN gallery TEXT',
        );
        await SeedData.insertAthletes(db);
      }
      if (oldVersion < 10) {
        await db.execute(
          'ALTER TABLE ${DatabaseSchema.products} ADD COLUMN gallery TEXT',
        );
        await SeedData.insertExtraProducts(db);
      }
      if (oldVersion < 11) await SeedData.applyGalleries(db);
      if (oldVersion < 12) {
        // Продавцы и модерация: только новые колонки и таблицы — данные
        // покупателей, корзина и заказы не трогаются.
        for (final String column in DatabaseSchema.productSellerColumns
            .split(',\n')
            .map((line) => line.trim())) {
          await db.execute('ALTER TABLE ${DatabaseSchema.products} ADD COLUMN $column');
        }
        await db.execute(
          'ALTER TABLE ${DatabaseSchema.orders} ADD COLUMN tracking_note TEXT',
        );
        await db.execute(DatabaseSchema.createSellers);
        await db.execute(DatabaseSchema.createSellerWarnings);
        await SeedData.insertSellers(db);
      }
      if (oldVersion < 13) {
        for (final String column in ['variants', 'try_on_image', 'try_on_meta']) {
          await db.execute(
            'ALTER TABLE ${DatabaseSchema.products} ADD COLUMN $column TEXT',
          );
        }
        await db.execute('ALTER TABLE ${DatabaseSchema.reviews} ADD COLUMN photos TEXT');
        await SeedData.applyGalleries(db);
        await SeedData.applyVariants(db);
        await SeedData.insertReviews(db);
      }
      if (oldVersion < 14) {
        await SeedData.applyGalleries(db);
        await SeedData.applyVariants(db);
        await SeedData.removePhotos(db);
      }
      if (oldVersion < 15) {
        await db.execute(
          'ALTER TABLE ${DatabaseSchema.products} ADD COLUMN composition TEXT',
        );
        await SeedData.insertUniversal(db);
      }
      if (oldVersion < 16) {
        for (final String column in [
          '${DatabaseSchema.products} ADD COLUMN diet TEXT',
          '${DatabaseSchema.orders} ADD COLUMN discount REAL NOT NULL DEFAULT 0',
          '${DatabaseSchema.reviews} ADD COLUMN verified INTEGER NOT NULL DEFAULT 0',
        ]) {
          await db.execute('ALTER TABLE $column');
        }
        await db.execute(DatabaseSchema.createNotifications);
        await db.execute(DatabaseSchema.createGameScores);
        await db.execute(DatabaseSchema.createCoupons);
        await SeedData.markVerifiedReviews(db);
        await SeedData.insertNutrition(db);
        await SeedData.insertGameScores(db);
      }
      if (oldVersion < 17) {
        // Если таблица продавцов создана только что (база старше v12),
        // колонки статуса в ней уже есть.
        final Set<String> existing = {
          for (final Map<String, Object?> row
              in await db.rawQuery('PRAGMA table_info(${DatabaseSchema.sellers})'))
            row['name']! as String,
        };
        for (final String column
            in DatabaseSchema.sellerStatusColumns.split(',\n')) {
          final String definition = column.trim();
          if (existing.contains(definition.split(' ').first)) continue;
          await db.execute(
            'ALTER TABLE ${DatabaseSchema.sellers} ADD COLUMN $definition',
          );
        }
        await db.execute(DatabaseSchema.createSellerAppeals);
      }
      return;
    }
    for (final String table in DatabaseSchema.tablesInDropOrder) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }
    await _onCreate(db, newVersion);
  }

  /// Количество записей в каждой таблице (проверка этапов 3–4).
  Future<Map<String, int>> tableCounts() async {
    final Database db = await database;
    final Map<String, int> counts = {};
    for (final String table in DatabaseSchema.tablesInCreateOrder) {
      final List<Map<String, Object?>> rows =
          await db.rawQuery('SELECT COUNT(*) AS count FROM $table');
      counts[table] = Sqflite.firstIntValue(rows) ?? 0;
    }
    return counts;
  }

  /// Удалить базу и создать заново с демо-данными.
  Future<void> reset() async {
    await close();
    await deleteDatabase(await _resolvePath());
    await database;
  }

  Future<void> close() async {
    final Future<Database>? opening = _opening;
    _opening = null;
    if (opening != null) {
      await (await opening).close();
    }
  }
}
