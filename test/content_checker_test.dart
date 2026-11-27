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

  test('протеин: «белый porosho.k - 70г» и материал «синтетика» — на проверку', () {
    final RiskReport report = ContentChecker.check(
      name: 'Протеин сывороточный',
      description: 'Вкусный протеин для набора массы',
      composition: 'белый porosho.k - 70г',
      material: 'синтетика',
      category: 'Спортивное питание',
      price: 12990,
    );
    expect(report.hold, isTrue);
    expect(report.reasons.map((r) => r.label),
        containsAll(['Иносказание о наркотиках',
          '«Синтетика» у спортивного питания — так называют синтетические наркотики']));
    // У футболки синтетика — обычная ткань.
    expect(ContentChecker.check(name: 'Футболка', material: 'синтетика',
        category: 'Одежда', price: 5990).flag, isFalse);
    // «Изотоник порошок» — обычный товар.
    expect(ContentChecker.check(name: 'Изотоник порошок 500 г',
        category: 'Спортивное питание', price: 5490).flag, isFalse);
  });

  test('отзыв «Наркошы эти задолбали» и ник на фото — товар в очередь админу', () {
    final RiskReport report = ContentChecker.check(
      name: 'Протеин', category: 'Спортивное питание', price: 12990,
      extra: [('в отзывах покупателей', 'Наркошы эти задолбали уже здесь')],
    );
    expect(report.flag, isTrue);
    expect(report.reasons.single.label, 'Покупатели пишут о наркотиках — в отзывах покупателей');
    final RiskReport photo = ContentChecker.check(
      name: 'Мяч', price: 9990, extra: [('на фото товара', 'BEST BALL t.me/fastshop_kz')],
    );
    expect(photo.reasons.map((r) => r.label),
        contains('Контакт для сделки вне магазина — на фото товара'));
    // Обычный отзыв ничего не меняет.
    expect(ContentChecker.check(name: 'Мяч', price: 9990,
        extra: [('в отзывах покупателей', 'Отличный мяч, сын доволен!')]).flag, isFalse);
  });

  test('слова латиницей «на слух»: mefedron, kokain', () {
    expect(check('Мяч', 'в подарок mefedron').hold, isTrue);
    expect(check('Мяч', 'есть kokain').hold, isTrue);
    expect(check('Повязка', 'снижает травматизм на тренировках').flag, isFalse);
  });
}
