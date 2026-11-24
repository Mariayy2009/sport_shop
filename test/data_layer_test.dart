import 'package:flutter_test/flutter_test.dart';
import 'package:sport_shop/core/di/app_dependencies.dart';
import 'package:sport_shop/core/errors/app_exception.dart';
import 'package:sport_shop/data/database/app_database.dart';
import 'package:sport_shop/data/datasources/local/session_local_datasource.dart';
import 'package:sport_shop/services/assistant/ai_key_store.dart';
import 'package:sport_shop/models/cart_item.dart';
import 'package:sport_shop/models/enums.dart';
import 'package:sport_shop/models/order.dart';
import 'package:sport_shop/models/order_item.dart';
import 'package:sport_shop/models/product.dart';
import 'package:sport_shop/models/product_filter.dart';
import 'package:sport_shop/models/recommendation_request.dart';
import 'package:sport_shop/models/recommended_product.dart';
import 'package:sport_shop/models/sport.dart';
import 'package:sport_shop/models/user.dart';
import 'package:sport_shop/state/cart_state.dart';
import 'package:sport_shop/state/order_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Проверка слоя данных на настоящей SQLite в памяти (без телефона).
void main() {
  late AppDatabase database;
  late AppDependencies deps;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = AppDatabase.withPath(inMemoryDatabasePath);
    deps = AppDependencies.local(
      database,
      sessionStorage: InMemorySessionStorage(),
      aiKeyStore: InMemoryAiKeyStore(),
    );
    await database.database;
  });

  tearDown(() => database.close());

  Future<int> sportId(String name) async {
    final List<Sport> sports = await deps.productRepository.getSports();
    return sports.firstWhere((sport) => sport.name == name).id!;
  }

  test('демо-данные записаны', () async {
    final Map<String, int> counts = await database.tableCounts();
    expect(counts['sports'], 9);
    expect(counts['categories'], 5);
    expect(counts['products'], 54);
    expect(counts['users'], 17); // покупатели, администратор, 2 продавца, 12 авторов отзывов
    expect(counts['orders'], 4);
  });

  group('Авторизация', () {
    test('успешный вход', () async {
      final User user = await deps.authService.login(
        email: 'MARIA@mail.kz',
        password: 'Maria123',
        rememberMe: true,
      );
      expect(user.firstName, 'Мария');
      expect(await deps.authService.restoreSession(), isNotNull);
    });

    test('неверный пароль', () {
      expect(
        deps.authService.login(
          email: 'maria@mail.kz',
          password: 'wrong123',
          rememberMe: false,
        ),
        throwsA(isA<AppException>()
            .having((error) => error.field, 'field', 'password')),
      );
    });

    test('неизвестный email', () {
      expect(
        deps.authService.login(
          email: 'nobody@mail.kz',
          password: 'Maria123',
          rememberMe: false,
        ),
        throwsA(isA<AppException>()
            .having((error) => error.field, 'field', 'email')),
      );
    });

    test('регистрация и повторный email', () async {
      final User user = await deps.authService.register(
        firstName: 'Айгерим',
        lastName: 'Серикова',
        email: 'aigerim@mail.kz',
        password: 'Aigerim1',
      );
      expect(user.id, isNotNull);
      expect(user.role, UserRole.customer);

      expect(
        deps.authService.register(
          firstName: 'Другая',
          lastName: 'Девушка',
          email: 'AIGERIM@mail.kz',
          password: 'Aigerim2',
        ),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('Каталог', () {
    test('поиск по кириллице без учёта регистра', () async {
      final List<Product> products = await deps.productRepository
          .getProducts(const ProductFilter(query: 'ФУТБОЛКА'));
      final List<String> names = products.map((p) => p.name).toList();
      expect(names, contains('Спортивная футболка'));
      expect(names, contains('Беговая футболка'));
    });

    test('фильтр по виду спорта и размеру', () async {
      final int volleyball = await sportId('Волейбол');
      final List<Product> products = await deps.productRepository.getProducts(
        ProductFilter(sportId: volleyball, size: 'M'),
      );
      expect(products, isNotEmpty);
      for (final Product product in products) {
        expect(product.sportName, 'Волейбол');
        expect(product.availableSizes, contains('M'));
      }
    });

    test('фильтр по цене', () async {
      final List<Product> products = await deps.productRepository
          .getProducts(const ProductFilter(maxPrice: 3000));
      expect(products.every((p) => p.price <= 3000), isTrue);
    });
  });

  group('AI-подбор', () {
    test('волейбол, опытный, стаж 6 лет', () async {
      final List<RecommendedProduct> result =
          await deps.recommendationService.getRecommendations(
        RecommendationRequest(
          sportId: await sportId('Волейбол'),
          level: SportLevel.experienced,
          experienceYears: 6,
          clothingSize: 'S',
          shoeSize: 38,
        ),
      );
      final List<String> mandatory = result
          .where((item) => item.isMandatory)
          .map((item) => item.product.name)
          .toList();
      expect(mandatory, contains('Волейбольная форма'));
      expect(mandatory, contains('Кроссовки для волейбола'));

      final List<String> all = result.map((item) => item.product.name).toList();
      expect(all, contains('Профессиональный мяч MIKASA'));
      // Без повторов
      expect(all.toSet().length, all.length);
    });

    test('бюджет ограничивает дополнительные товары', () async {
      final List<RecommendedProduct> result =
          await deps.recommendationService.getRecommendations(
        RecommendationRequest(
          sportId: await sportId('Волейбол'),
          level: SportLevel.experienced,
          experienceYears: 6,
          budget: 30000,
        ),
      );
      expect(result.where((item) => !item.isMandatory), isEmpty);
    });
  });

  group('Заказы', () {
    test('оформление уменьшает остаток', () async {
      final Product product =
          (await deps.productRepository.getProductById(1))!;

      final Order saved = await deps.orderRepository.createOrder(Order(
        userId: 2,
        status: OrderStatus.newOrder,
        totalPrice: product.price * 2,
        createdAt: DateTime.now(),
        items: [
          OrderItem(productId: product.id!, quantity: 2, price: product.price),
        ],
      ));

      expect(saved.id, greaterThan(1024));
      final Product updated =
          (await deps.productRepository.getProductById(1))!;
      expect(updated.stock, product.stock - 2);

      final List<Order> history = await deps.orderRepository.getOrdersByUser(2);
      expect(history.length, 4);
    });

    test('нельзя заказать больше, чем есть на складе', () async {
      final Product product =
          (await deps.productRepository.getProductById(1))!;
      await expectLater(
        deps.orderRepository.createOrder(Order(
          userId: 2,
          status: OrderStatus.newOrder,
          totalPrice: 0,
          createdAt: DateTime.now(),
          items: [
            OrderItem(
              productId: product.id!,
              quantity: product.stock + 1,
              price: product.price,
            ),
          ],
        )),
        throwsA(isA<AppException>()),
      );
      // Транзакция откатилась — заказов столько же, сколько было
      expect((await deps.orderRepository.getOrdersByUser(2)).length, 3);
    });
  });

  group('Корзина', () {
    test('размер обязателен, позиции по размерам, сохранение, очистка',
        () async {
      final CartState cart = CartState(deps.cartRepository);
      await cart.setUser(2);
      final Product uniform =
          (await deps.productRepository.getProductById(1))!;

      await expectLater(cart.add(uniform), throwsA(isA<AppException>()));

      await cart.add(uniform, size: 'M');
      await cart.add(uniform, size: 'M');
      await cart.add(uniform, size: 'L');
      expect(cart.items.length, 2);
      expect(cart.totalQuantity, 3);

      // Корзина хранится в базе — новый объект видит те же товары.
      final CartState sameUser = CartState(deps.cartRepository);
      await sameUser.setUser(2);
      expect(sameUser.totalQuantity, 3);

      await cart.clear();
      expect(cart.isEmpty, isTrue);
    });
  });

  group('Оформление заказа', () {
    test('итог = товары + доставка, размер сохраняется', () async {
      final OrderState orders = OrderState(deps.orderRepository);
      await orders.setUser(2);
      final Product kneePads =
          (await deps.productRepository.getProductById(2))!;

      final Order order = await orders.placeOrder(
        userId: 2,
        items: [CartItem(product: kneePads, quantity: 2, selectedSize: 'M')],
        customerName: 'Мария Габдулина',
        phone: '+7 708 777 5555',
        deliveryMethod: DeliveryMethod.courier,
        address: 'г. Астана, пр. Абая, д. 10',
      );

      expect(order.totalPrice, kneePads.price * 2 + 300);
      final Order? saved = await deps.orderRepository.getOrderById(order.id!);
      expect(saved!.items.first.size, 'M');
    });
  });
}
