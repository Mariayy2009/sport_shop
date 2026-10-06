import 'package:sqflite/sqflite.dart';

import '../../../models/user.dart';
import '../../../models/user_sizes.dart';
import '../../database/app_database.dart';
import '../../database/database_schema.dart';

/// SQL-запросы к таблицам users и user_sizes.
class UserLocalDataSource {
  UserLocalDataSource(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<User?> findByEmail(String email) async {
    final Database db = await _appDatabase.database;
    // Колонка email объявлена с COLLATE NOCASE — поиск без учёта регистра.
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseSchema.users,
      where: 'email = ?',
      whereArgs: [email.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  Future<User?> findById(int id) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseSchema.users,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  Future<List<User>> getAll() async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows =
        await db.query(DatabaseSchema.users, orderBy: 'created_at DESC');
    return rows.map(User.fromMap).toList();
  }

  Future<User> insert(User user) async {
    final Database db = await _appDatabase.database;
    final int id =
        await db.insert(DatabaseSchema.users, user.toMap()..remove('id'));
    return user.copyWith(id: id);
  }

  Future<User> update(User user) async {
    final int? id = user.id;
    if (id == null) {
      throw ArgumentError('Нельзя обновить пользователя без id');
    }
    final Database db = await _appDatabase.database;
    await db.update(
      DatabaseSchema.users,
      user.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
    );
    return user;
  }

  Future<UserSizes?> getSizes(int userId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT us.*, s.name AS sport_name '
      'FROM ${DatabaseSchema.userSizes} us '
      'LEFT JOIN ${DatabaseSchema.sports} s ON s.id = us.sport_id '
      'WHERE us.user_id = ? LIMIT 1',
      [userId],
    );
    return rows.isEmpty ? null : UserSizes.fromMap(rows.first);
  }

  /// Создаёт запись параметров или обновляет существующую (связь 1:1).
  Future<UserSizes> saveSizes(UserSizes sizes) async {
    final Database db = await _appDatabase.database;
    final Map<String, Object?> values = sizes.toMap()..remove('id');
    final List<Map<String, Object?>> existing = await db.query(
      DatabaseSchema.userSizes,
      columns: ['id'],
      where: 'user_id = ?',
      whereArgs: [sizes.userId],
      limit: 1,
    );

    if (existing.isEmpty) {
      final int id = await db.insert(DatabaseSchema.userSizes, values);
      return sizes.copyWith(id: id);
    }

    final int id = existing.first['id']! as int;
    await db.update(
      DatabaseSchema.userSizes,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
    return sizes.copyWith(id: id);
  }
}
