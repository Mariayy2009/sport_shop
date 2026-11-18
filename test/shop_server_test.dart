import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_shop/core/di/app_dependencies.dart';
import 'package:sport_shop/core/errors/app_exception.dart';
import 'package:sport_shop/data/database/app_database.dart';
import 'package:sport_shop/data/datasources/local/session_local_datasource.dart';
import 'package:sport_shop/data/datasources/local/shop_server_storage.dart';
import 'package:sport_shop/data/datasources/remote/shop_api_client.dart';
import 'package:sport_shop/data/repositories/api_product_repository.dart';
import 'package:sport_shop/data/repositories/try_on_repository.dart';
import 'package:sport_shop/models/product.dart';
import 'package:sport_shop/models/product_filter.dart';
import 'package:sport_shop/services/assistant/ai_key_store.dart';
import 'package:sport_shop/state/data_source_state.dart';
import 'package:sport_shop/state/product_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ответ JSON в UTF-8 (кириллица).
http.Response json(Object? body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json'});

const Map<String, Object?> serverProduct = {
  'id': 501,
  'name': 'Мяч с сервера',
  'description': 'Из PostgreSQL',
  'price': 9990.0,
  'category_id': 5,
  'sport_id': 1,
  'size': null,
  'stock': 3,
  'image_url': 'assets/images/products/mikasa_ball.jpg',
  'brand': 'Mikasa',
  'material': null,
  'rating': 4.5,
  'reviews_count': 2,
  'category_name': 'Инвентарь',
  'sport_name': 'Волейбол',
};

/// Сервер-заглушка: каталог из одного товара.
MockClient fakeShop({List<Uri>? requests, bool down = false}) {
  return MockClient((request) async {
    requests?.add(request.url);
    if (down) throw const SocketException('нет сети');
    return switch (request.url.path) {
      '/health' => json({'status': 'ok', 'database': 'PostgreSQL 16.4', 'products': 1}),
      '/products' => json([serverProduct]),
      '/products/501' => json(serverProduct),
      '/products/7' => json({'detail': 'Товар не найден'}, 404),
      '/sports' => json([{'id': 1, 'name': 'Волейбол', 'description': null}]),
      '/categories' => json([{'id': 5, 'name': 'Инвентарь', 'sport_id': null}]),
      '/broken' => json({'detail': 'Нет связи с PostgreSQL: OperationalError'}, 503),
      _ => json({'detail': 'Not Found'}, 404),
    };
  });
}

void main() {
  test('адрес сервера магазина', () {
    expect(ShopApiClient.normalizeUrl('192.168.1.5'), 'http://192.168.1.5:8080');
    expect(ShopApiClient.normalizeUrl('10.0.2.2:9000'), 'http://10.0.2.2:9000');
    expect(ShopApiClient.normalizeUrl('ftp://x'), isNull);
    expect(ShopApiClient.normalizeUrl(''), isNull);
  });

  group('Каталог с сервера', () {
    test('товары, виды спорта и категории в формате приложения', () async {
      final ApiProductRepository repository =
          ApiProductRepository(ShopApiClient('http://x:8080', fakeShop()));
      final Product product = (await repository.getProducts()).single;
      expect(product.name, 'Мяч с сервера');
      expect(product.price, 9990);
      expect(product.categoryName, 'Инвентарь');
      expect((await repository.getProductById(501))!.brand, 'Mikasa');
      expect(await repository.getProductById(7), isNull);
      expect((await repository.getSports()).single.name, 'Волейбол');
      expect((await repository.getCategories()).single.name, 'Инвентарь');
    });

    test('фильтры каталога уходят параметрами запроса', () async {
      final List<Uri> requests = [];
      final ApiProductRepository repository = ApiProductRepository(
        ShopApiClient('http://x:8080', fakeShop(requests: requests)),
      );
      await repository.getProducts(const ProductFilter(
        query: ' мяч ',
        sportId: 1,
        size: 'M',
        maxPrice: 20000,
        onlyAvailable: true,
      ));
      expect(requests.single.queryParameters, {
        'query': 'мяч',
        'sport_id': '1',
        'size': 'M',
        'max_price': '20000.0',
        'only_available': 'true',
      });
    });

    test('изменение товаров на этом этапе — понятный отказ', () async {
      final ApiProductRepository repository =
          ApiProductRepository(ShopApiClient('http://x:8080', fakeShop()));
      await expectLater(repository.deleteProduct(1), throwsA(isA<AppException>()));
    });

    test('ошибки сети и сервера — текстом для пользователя', () async {
      await expectLater(
        ShopApiClient('http://x:8080', fakeShop(down: true)).getJson('/products'),
        throwsA(isA<AppException>().having((e) => e.message, 'message', contains('Нет связи'))),
      );
      await expectLater(
        ShopApiClient('http://x:8080', fakeShop()).getJson('/broken'),
        throwsA(isA<AppException>().having((e) => e.message, 'message', contains('PostgreSQL'))),
      );
    });
  });

  group('Переключение источника данных', () {
    late AppDatabase database;
    late AppDependencies deps;
    late InMemoryShopServerStorage storage;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      database = AppDatabase.withPath(inMemoryDatabasePath);
      storage = InMemoryShopServerStorage();
      deps = AppDependencies.local(
        database,
        sessionStorage: InMemorySessionStorage(),
        aiKeyStore: InMemoryAiKeyStore(),
        tryOnRepository: InMemoryTryOnRepository(),
        shopServerStorage: storage,
      );
      await database.database;
    });

    tearDown(() => database.close());

    DataSourceState state(ProductState catalog, {bool down = false}) => DataSourceState(
          products: deps.productRepository,
          storage: storage,
          catalog: catalog,
          client: fakeShop(down: down),
        );

    test('сервер ↔ телефон без перезапуска', () async {
      final ProductState catalog = ProductState(deps.productRepository);
      final DataSourceState source = state(catalog);
      await source.restore();
      await catalog.init();
      expect(catalog.products.length, 38); // SQLite на телефоне

      expect(await source.connect('192.168.1.5'), isNull);
      expect(source.usesServer, isTrue);
      expect(storage.url, 'http://192.168.1.5:8080');
      expect(source.status!.database, 'PostgreSQL 16.4');
      expect(catalog.products.single.name, 'Мяч с сервера');

      await source.useLocal();
      expect(source.usesServer, isFalse);
      expect(storage.url, isNull);
      expect(catalog.products.length, 38);
    });

    test('сохранённый сервер не отвечает — работает каталог телефона', () async {
      storage.url = 'http://192.168.1.5:8080';
      final ProductState catalog = ProductState(deps.productRepository);
      final DataSourceState source = state(catalog, down: true);
      await source.restore();
      await catalog.init();
      expect(source.usesServer, isFalse);
      expect(source.serverUnavailable, isTrue);
      expect(catalog.products.length, 38);
      // Адрес не теряется: можно повторить позже.
      expect(source.serverUrl, 'http://192.168.1.5:8080');
      expect(await source.retry(), contains('Нет связи'));
    });

    test('неверный адрес не сохраняется', () async {
      final DataSourceState source = state(ProductState(deps.productRepository));
      expect(await source.connect('не адрес'), contains('192.168'));
      expect(storage.url, isNull);
    });
  });
}
