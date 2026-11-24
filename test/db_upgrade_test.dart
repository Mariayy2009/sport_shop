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
        await db.execute(statement.replaceAll('gallery TEXT,', ''));
      }
      for (final String sport in [
        'Волейбол', 'Бег', 'Футбол', 'Плавание', 'Бокс', 'Карате',
        'Баскетбол', 'Йога', 'Фитнес',
      ]) {
        await db.insert('sports', {'name': sport, 'description': ''});
      }
      for (final String category in [
        'Одежда', 'Обувь', 'Аксессуары', 'Защита', 'Инвентарь',
      ]) {
        await db.insert('categories', {'name': category});
      }
      // Товар покупателя в корзине должен пережить обновление.
      await db.insert('products', {
        'name': 'Кимоно для карате',
        'price': 15990.0,
        'category_id': 1,
        'sport_id': 6,
        'stock': 3,
        'image_url': 'assets/images/products/karate_kimono.jpg',
        'brand': 'Adidas',
      });
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

    // v10: новые товары и варианты одного продавца.
    final List<Map<String, Object?>> products = await db.query('products');
    expect(products.length, 17);
    final List<Map<String, Object?>> kimonos = products
        .where((row) => (row['name']! as String).startsWith('Кимоно'))
        .toList();
    expect(kimonos.length, 3);
    expect(kimonos.every((row) => row['brand'] == 'Budo Pro'), isTrue);
    final Map<String, Object?> uniform = products
        .firstWhere((row) => row['name'] == 'Форма волейбольная женская');
    expect((uniform['gallery']! as String).split('\n'), hasLength(7));

    // v11: у товаров основного каталога появились фото.
    final Map<String, Object?> kimono = products.firstWhere(
        (row) => row['image_url'] == 'assets/images/products/karate_kimono.jpg');
    expect(kimono['brand'], 'Budo Pro');
    await db.close();
    await deleteDatabase(path);
  });
}
