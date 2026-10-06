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

  /// Учебная версия: при смене схемы база пересоздаётся с демо-данными.
  /// В дипломе здесь будут пошаговые миграции без потери данных.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
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
