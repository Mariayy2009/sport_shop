import 'package:flutter_test/flutter_test.dart';
import 'package:sport_shop/core/di/app_dependencies.dart';
import 'package:sport_shop/data/database/app_database.dart';
import 'package:sport_shop/data/datasources/local/session_local_datasource.dart';
import 'package:sport_shop/data/repositories/moderation_repository.dart';
import 'package:sport_shop/data/repositories/preferences_repository.dart';
import 'package:sport_shop/models/enums.dart';
import 'package:sport_shop/models/order.dart';
import 'package:sport_shop/models/order_item.dart';
import 'package:sport_shop/models/product.dart';
import 'package:sport_shop/models/product_filter.dart';
import 'package:sport_shop/models/question.dart';
import 'package:sport_shop/models/user.dart';
import 'package:sport_shop/services/assistant/ai_key_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDependencies deps;

  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    deps = AppDependencies.local(
      AppDatabase.withPath(inMemoryDatabasePath),
      sessionStorage: InMemorySessionStorage(),
      aiKeyStore: InMemoryAiKeyStore(),
      preferencesRepository: InMemoryPreferencesRepository(),
    );
  });

  Future<User> login(String email, String password) =>
      deps.authService.login(email: email, password: password, rememberMe: false);

  test('продавец входит и видит свой магазин и товары', () async {
    final User seller = await login('budo@sport.kz', 'Seller123');
    expect(seller.role, UserRole.seller);
    expect(seller.isSeller, isTrue);
    expect(seller.shopName, 'Budo Pro');
    final List<Product> mine = await deps.productRepository
        .getProducts(ProductFilter(sellerId: seller.id, includeBlocked: true));
    expect(mine.map((p) => p.name),
        containsAll(['Кимоно для карате', 'Кимоно киокушинкай']));
    expect(mine.every((p) => p.sellerName == 'Budo Pro'), isTrue);
    // Покупатель и администратор — не продавцы.
    expect((await login('maria@mail.kz', 'Maria123')).isSeller, isFalse);
    expect((await login('admin@sport.kz', 'Admin123')).isAdmin, isTrue);
  });

  test('администратор снимает товар с продажи — покупатели его не видят, '
      'продавец получает предупреждение', () async {
    final User seller = await login('budo@sport.kz', 'Seller123');
    final List<Product> all = await deps.productRepository.getProducts();
    final Product kimono = all.firstWhere((p) => p.name == 'Кимоно киокушинкай');
    final ModerationRepository moderation = deps.moderationRepository;

    await moderation.blockProduct(kimono, WarningReason.fraud, text: 'Фото чужого товара');
    final List<Product> catalog = await deps.productRepository.getProducts();
    expect(catalog.any((p) => p.id == kimono.id), isFalse);
    final Product blocked = (await deps.productRepository.getProductById(kimono.id!))!;
    expect(blocked.isBlocked, isTrue);
    expect(blocked.blockReason, 'Подозрение на мошенничество');

    expect(await moderation.unreadCount(seller.id!), 1);
    final SellerWarning warning = (await moderation.warningsFor(seller.id!)).single;
    expect(warning.reason, WarningReason.fraud);
    expect(warning.productName, 'Кимоно киокушинкай');
    expect(warning.text, contains('Фото чужого товара'));
    await moderation.markRead(seller.id!);
    expect(await moderation.unreadCount(seller.id!), 0);

    await moderation.unblockProduct(kimono.id!);
    expect((await deps.productRepository.getProducts()).any((p) => p.id == kimono.id), isTrue);
  });

  test('продавец видит заказы и вопросы о своих товарах, пишет «где товар»', () async {
    final User seller = await login('budo@sport.kz', 'Seller123');
    final User buyer = await login('maria@mail.kz', 'Maria123');
    final Product kimono = (await deps.productRepository.getProducts())
        .firstWhere((p) => p.name == 'Кимоно киокушинкай');

    final Order order = await deps.orderRepository.createOrder(Order(
      userId: buyer.id!,
      status: OrderStatus.newOrder,
      totalPrice: kimono.price,
      createdAt: DateTime.now(),
      items: [OrderItem(productId: kimono.id!, quantity: 1, price: kimono.price, size: '160')],
    ));
    final List<Order> sellerOrders = await deps.orderRepository.getOrdersForSeller(seller.id!);
    expect(sellerOrders.map((o) => o.id), contains(order.id));

    await deps.orderRepository.updateTracking(order.id!, 'Отправлен из Алматы');
    expect((await deps.orderRepository.getOrderById(order.id!))!.trackingNote,
        'Отправлен из Алматы');

    await deps.feedbackRepository.askQuestion(Question(
      productId: kimono.id!,
      userId: buyer.id!,
      text: 'Есть размер 150?',
      createdAt: DateTime.now(),
    ));
    final List<Question> questions =
        await deps.feedbackRepository.getQuestionsForSeller(seller.id!);
    expect(questions.single.text, 'Есть размер 150?');
  });
}
