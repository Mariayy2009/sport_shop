// Выгрузка демо-каталога из приложения в backend/seed/catalog.json.
//
// Источник один — seed_data.dart: сервер получает те же виды спорта,
// категории и товары с теми же номерами, что и база на телефоне.
//
// Запуск:  flutter test tools/export_seed_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sport_shop/data/database/app_database.dart';
import 'package:sport_shop/data/database/database_schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('выгрузка каталога', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final AppDatabase database = AppDatabase.withPath(inMemoryDatabasePath);
    final Database db = await database.database;
    Future<List<Map<String, Object?>>> table(String name) =>
        db.query(name, orderBy: 'id');
    final Map<String, Object?> catalog = {
      'sports': await table(DatabaseSchema.sports),
      'categories': await table(DatabaseSchema.categories),
      'products': await table(DatabaseSchema.products),
    };
    final File file = File('backend/seed/catalog.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(catalog),
    );
    await database.close();
    // ignore: avoid_print
    print('Записано: ${file.path}');
  });
}
