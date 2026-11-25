import 'package:flutter_test/flutter_test.dart';
import 'package:sport_shop/data/database/app_database.dart';
import 'package:sport_shop/data/datasources/local/product_local_datasource.dart';
import 'package:sport_shop/data/repositories/local_product_repository.dart';
import 'package:sport_shop/models/product.dart';
import 'package:sport_shop/services/moderation/content_checker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

RiskReport check(String name, String description, {double price = 9990, double? median}) =>
    ContentChecker.check(name: name, description: description, price: price, medianPrice: median);

void main() {
  test('обычные товары каталога проверку проходят', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final List<Product> all = await LocalProductRepository(
      ProductLocalDataSource(AppDatabase.withPath(inMemoryDatabasePath)),
    ).getProducts();
    for (final Product p in all) {
      final RiskReport report = ContentChecker.check(
        name: p.name,
        description: p.description,
        composition: p.composition,
        price: p.price,
      );
      expect(report.flag, isFalse,
          reason: '${p.name}: ${report.reasons.map((r) => r.label)}');
    }
  });

  test('обычное описание мяча, а в самом конце — отсылка к наркотикам', () {
    final String long = 'Мяч для футбола, размер 5, прошитые панели, ' * 8;
    final RiskReport report = check(
      'Мяч футбольный',
      '$long\n\n\n\nкому надо — пишите, есть м е ф и ❄',
    );
    expect(report.hold, isTrue);
    expect(report.reasons.map((r) => r.label), contains(contains('спрятано в конце')));
    expect(report.reasons.map((r) => r.label),
        contains('Эмодзи, которыми обозначают наркотики'));
  });

  test('латинские буквы вместо русских и точки между буквами не помогают', () {
    expect(check('Мяч', 'в комплекте мeфeдpoн').hold, isTrue); // e, p, o — латиница
    expect(check('Мяч', 'м.е.ф.е.д.р.о.н в наличии').hold, isTrue);
    expect(check('Перчатки', 'с​т​е​р​о​и​д​ы').hold, isTrue);
  });

  test('допинг и оружие — на проверку; «нестероидная мазь» — нет', () {
    expect(check('Банка', 'курс тестостерона для массы').hold, isTrue);
    expect(check('Брелок', 'кастет из стали').hold, isTrue);
    expect(check('Мазь', 'нестероидный противовоспалительный гель').flag, isFalse);
  });

  test('контакты для сделки вне магазина и странная цена — в очередь админу', () {
    final RiskReport report = check('Кроссовки', 'Дешевле в телеграм @sportdeal_kz',
        price: 990, median: 30000);
    expect(report.flag, isTrue);
    expect(report.reasons.map((r) => r.label),
        containsAll(['Контакт для сделки вне магазина', 'Цена подозрительно низкая']));
  });
}
