import 'package:flutter_test/flutter_test.dart';
import 'package:sport_shop/data/database/app_database.dart';
import 'package:sport_shop/data/database/database_schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('обновление базы с версии 8: данные сохраняются, спортсмены добавляются', () async {
    final String path = '${DateTime.now().microsecondsSinceEpoch}_v8.db';
    // База версии 8: таблица экспонатов без gallery и одна запись в корзине.
    final Database old = await openDatabase(path, version: 8, onCreate: (db, _) async {
      for (final String statement in DatabaseSchema.createStatements) {
        await db.execute(statement.replaceFirst('gallery TEXT,', ''));
      }
      await db.insert('sports', {'name': 'Бокс', 'description': ''});
      await db.insert('exhibits', {
        'title': 'Экспонат КНУС',
        'athlete': 'Федерация',
        'source': 'knus',
        'created_at': '2026-11-16T00:00:00.000',
      });
    });
    await old.close();

    final AppDatabase upgraded = AppDatabase.withPath(path);
    final Database db = await upgraded.database;
    final List<Map<String, Object?>> exhibits =
        await db.query('exhibits', orderBy: 'created_at DESC');
    expect(exhibits.length, 12);
    expect(exhibits.last['title'], 'Экспонат КНУС');
    expect(exhibits.first['title'], 'Михаил Шайдоров');
    expect(exhibits.first['gallery'], contains('shaidorov_2'));
    final Map<String, Object?> golovkin =
        exhibits.firstWhere((row) => row['title'] == 'Геннадий Головкин');
    expect(golovkin['sport_id'], isNotNull);
    await db.close();
    await deleteDatabase(path);
  });
}
