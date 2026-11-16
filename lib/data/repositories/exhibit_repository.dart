import 'package:sqflite/sqflite.dart';

import '../../models/exhibit.dart';
import '../database/app_database.dart';
import '../database/database_schema.dart';

/// Контракт работы с экспонатами «Зала славы».
abstract class ExhibitRepository {
  /// Все экспонаты, сначала добавленные последними.
  Future<List<Exhibit>> getAll();

  Future<Exhibit?> getById(int id);

  /// Создаёт экспонат (id == null) или обновляет существующий.
  Future<void> save(Exhibit exhibit);

  Future<void> delete(int id);
}

class LocalExhibitRepository implements ExhibitRepository {
  LocalExhibitRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  static const String _select = 'SELECT e.*, s.name AS sport_name '
      'FROM ${DatabaseSchema.exhibits} e '
      'LEFT JOIN ${DatabaseSchema.sports} s ON s.id = e.sport_id';

  @override
  Future<List<Exhibit>> getAll() async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows =
        await db.rawQuery('$_select ORDER BY e.created_at DESC, e.id DESC');
    return rows.map(Exhibit.fromMap).toList();
  }

  @override
  Future<Exhibit?> getById(int id) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows =
        await db.rawQuery('$_select WHERE e.id = ? LIMIT 1', [id]);
    return rows.isEmpty ? null : Exhibit.fromMap(rows.first);
  }

  @override
  Future<void> save(Exhibit exhibit) async {
    final Database db = await _appDatabase.database;
    final Map<String, Object?> values = exhibit.toMap()..remove('id');
    if (exhibit.id == null) {
      await db.insert(DatabaseSchema.exhibits, values);
    } else {
      await db.update(
        DatabaseSchema.exhibits,
        values,
        where: 'id = ?',
        whereArgs: [exhibit.id],
      );
    }
  }

  @override
  Future<void> delete(int id) async {
    final Database db = await _appDatabase.database;
    await db.delete(DatabaseSchema.exhibits, where: 'id = ?', whereArgs: [id]);
  }
}
