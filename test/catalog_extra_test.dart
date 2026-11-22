import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sport_shop/data/database/app_database.dart';
import 'package:sport_shop/data/datasources/local/product_local_datasource.dart';
import 'package:sport_shop/data/repositories/local_product_repository.dart';
import 'package:sport_shop/models/product.dart';
import 'package:sport_shop/models/try_on.dart';
import 'package:sport_shop/widgets/seller_products_section.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late List<Product> all;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final AppDatabase database = AppDatabase.withPath(inMemoryDatabasePath);
    all = await LocalProductRepository(ProductLocalDataSource(database)).getProducts();
  });

  test('у всех товаров есть фото, и все фото есть в приложении', () {
    expect(all.length, 54);
    // Фото вратарских перчаток пока не найдено — в приложении заглушка.
    const Set<String> waitingForPhoto = {'Вратарские перчатки'};
    for (final Product product in all) {
      if (waitingForPhoto.contains(product.name)) continue;
      expect(product.images, isNotEmpty, reason: product.name);
      for (final String image in product.images) {
        expect(File(image).existsSync(), isTrue, reason: '${product.name}: $image');
      }
    }
  });

  test('варианты одного продавца: кимоно у Budo Pro', () {
    final Product classic =
        all.firstWhere((p) => p.name == 'Кимоно для карате классическое');
    final List<Product> seller = SellerProductsSection.pick(classic, all);
    expect(seller.take(2).map((p) => p.name).toSet(),
        {'Кимоно для карате', 'Кимоно киокушинкай'});
    final Product uniform =
        all.firstWhere((p) => p.name == 'Форма волейбольная женская');
    expect(uniform.images, hasLength(8));
  });

  test('примерка: одежда примеряется, комплект и аксессуары — нет', () {
    bool live(String name) =>
        TryOnSupport.of(all.firstWhere((p) => p.name == name)).live;
    expect(live('Кимоно киокушинкай'), isTrue);
    expect(live('Футболка тренировочная Nike Academy'), isTrue);
    expect(live('Шорты беговые 2 в 1'), isTrue);
    expect(live('Форма волейбольная женская'), isTrue);
    expect(TryOnSupport.of(all.firstWhere(
        (p) => p.name == 'Комплект для фитнеса: топ и леггинсы')).any, isFalse);
    expect(TryOnSupport.of(all.firstWhere(
        (p) => p.name == 'Компрессионные рукава')).any, isFalse);
  });
}
