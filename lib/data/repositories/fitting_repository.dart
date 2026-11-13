import 'package:sqflite/sqflite.dart';

import '../../models/fitting_photos.dart';
import '../database/app_database.dart';
import '../database/database_schema.dart';

/// Контракт хранения фото для примерки.
abstract class FittingRepository {
  Future<FittingPhotos?> get(int userId);

  Future<void> save(FittingPhotos photos);

  Future<void> delete(int userId);
}

class LocalFittingRepository implements FittingRepository {
  LocalFittingRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<FittingPhotos?> get(int userId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseSchema.fittingPhotos,
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isEmpty ? null : FittingPhotos.fromMap(rows.first);
  }

  @override
  Future<void> save(FittingPhotos photos) async {
    final Database db = await _appDatabase.database;
    await db.insert(
      DatabaseSchema.fittingPhotos,
      photos.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(int userId) async {
    final Database db = await _appDatabase.database;
    await db.delete(
      DatabaseSchema.fittingPhotos,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }
}
