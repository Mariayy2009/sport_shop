import 'package:flutter_test/flutter_test.dart';
import 'package:sport_shop/core/di/app_dependencies.dart';
import 'package:sport_shop/data/database/app_database.dart';
import 'package:sport_shop/data/datasources/local/session_local_datasource.dart';
import 'package:sport_shop/data/repositories/game_repository.dart';
import 'package:sport_shop/data/repositories/order_repository.dart';
import 'package:sport_shop/data/repositories/preferences_repository.dart';
import 'package:sport_shop/models/app_notification.dart';
import 'package:sport_shop/models/cart_item.dart';
import 'package:sport_shop/models/coupon.dart';
import 'package:sport_shop/models/enums.dart';
import 'package:sport_shop/models/order.dart';
import 'package:sport_shop/models/order_item.dart';
import 'package:sport_shop/models/product.dart';
import 'package:sport_shop/models/product_filter.dart';
import 'package:sport_shop/models/question.dart';
import 'package:sport_shop/models/review.dart';
import 'package:sport_shop/models/user.dart';
import 'package:sport_shop/services/assistant/ai_key_store.dart';
import 'package:sport_shop/state/cart_state.dart';
import 'package:sport_shop/state/order_state.dart';
import 'package:sport_shop/widgets/protein_calculator_sheet.dart';
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

  Future<Product> productNamed(String name) async =>
      (await deps.productRepository.getProducts(const ProductFilter(includeBlocked: true)))
          .firstWhere((p) => p.name == name);

  test('ответ продавца и статус заказа приходят покупателю уведомлением', () async {
    final User buyer = await login('maria@mail.kz', 'Maria123');
    final Product kimono = await productNamed('Кимоно киокушинкай');
    await deps.feedbackRepository.askQuestion(Question(
      productId: kimono.id!,
      userId: buyer.id!,
      text: 'Есть рост 160?',
      createdAt: DateTime.now(),
    ));
    final Question question = (await deps.feedbackRepository.getQuestions(kimono.id!))
        .firstWhere((q) => q.text == 'Есть рост 160?');
    await deps.feedbackRepository.answerQuestion(question.id!, 'Да, есть');

    final Order order = await deps.orderRepository.createOrder(Order(
      userId: buyer.id!,
      status: OrderStatus.newOrder,
      totalPrice: kimono.price,
      createdAt: DateTime.now(),
      items: [OrderItem(productId: kimono.id!, quantity: 1, price: kimono.price)],
    ));
    await deps.orderRepository.updateStatus(order.id!, OrderStatus.inTransit);

    final List<AppNotification> list =
        await deps.notificationRepository.forUser(buyer.id!);
    expect(list.map((n) => n.title), contains('Продавец ответил на ваш вопрос'));
    expect(list.map((n) => n.title), contains('Заказ №${order.id}: в пути'));
    expect(await deps.notificationRepository.unreadCount(buyer.id!), 2);
    await deps.notificationRepository.markAllRead(buyer.id!);
    expect(await deps.notificationRepository.unreadCount(buyer.id!), 0);
  });

  test('товар заканчивается — продавцу уведомление; статистика продаж', () async {
    final User seller = await login('sportlife@sport.kz', 'Seller123');
    final User buyer = await login('maria@mail.kz', 'Maria123');
    // Растительного протеина в демо-данных 3 шт.
    final Product protein = await productNamed('Протеин растительный гороховый 750 г');
    expect(protein.isLowStock, isTrue);
    await deps.orderRepository.createOrder(Order(
      userId: buyer.id!,
      status: OrderStatus.newOrder,
      totalPrice: protein.price,
      createdAt: DateTime.now(),
      items: [OrderItem(productId: protein.id!, quantity: 1, price: protein.price)],
    ));
    final List<AppNotification> list =
        await deps.notificationRepository.forUser(seller.id!);
    expect(list.first.title, 'Товар заканчивается');
    expect(list.first.body, contains('осталось 2 шт.'));

    final SellerStats stats = await deps.orderRepository.sellerStats(seller.id!);
    expect(stats.sold, greaterThanOrEqualTo(1));
    expect(stats.monthRevenue, greaterThanOrEqualTo(protein.price));
    expect(stats.top.map((t) => t.$1), contains(protein.name));
  });

  test('рекорд в игре: таблица рекордов и промокод 5% только на мячи', () async {
    final User buyer = await login('maria@mail.kz', 'Maria123');
    final GameRepository games = deps.gameRepository;
    final GameResult low = await games.saveScore(buyer.id!, 'football', 4);
    expect(low.coupon, isNull);
    final GameResult high = await games.saveScore(buyer.id!, 'football', 31);
    expect(high.isRecord, isTrue);
    expect(high.coupon, isNotNull);
    // Второй промокод, пока первый не использован, не выдаётся.
    expect((await games.saveScore(buyer.id!, 'football', 40)).coupon, isNull);

    final List<LeaderboardEntry> leaders = await games.leaderboard('football');
    expect(leaders.first.userId, buyer.id);
    expect(leaders.first.score, 40);

    final Coupon coupon = (await games.findCoupon(buyer.id!, high.coupon!.code.toLowerCase()))!;
    final Product ball = await productNamed('Мяч волейбольный Mikasa V200W');
    final Product bottle = (await deps.productRepository.getProducts())
        .firstWhere((p) => !p.name.toLowerCase().contains('мяч'));
    final double discount = OrderState.discountFor([
      CartItem(product: ball, quantity: 1),
      CartItem(product: bottle, quantity: 1),
    ], coupon);
    expect(discount, (ball.price * 0.05).roundToDouble());
    await games.useCoupon(coupon.id);
    expect(await games.findCoupon(buyer.id!, coupon.code), isNull);
  });

  test('отзыв после покупки отмечается «покупатель подтверждён»', () async {
    final User buyer = await login('maria@mail.kz', 'Maria123');
    final Product ball = await productNamed('Мяч волейбольный Mikasa V200W');
    await deps.orderRepository.createOrder(Order(
      userId: buyer.id!,
      status: OrderStatus.newOrder,
      totalPrice: ball.price,
      createdAt: DateTime.now(),
      items: [OrderItem(productId: ball.id!, quantity: 1, price: ball.price)],
    ));
    await deps.feedbackRepository.saveReview(Review(
      userId: buyer.id!,
      productId: ball.id!,
      rating: 5,
      text: 'Отличный мяч',
      createdAt: DateTime.now(),
    ));
    final Review mine = (await deps.feedbackRepository.getReviews(ball.id!))
        .firstWhere((r) => r.userId == buyer.id);
    expect(mine.verified, isTrue);
  });

  test('спортпит: фильтр «веган» и калькулятор порций', () async {
    final List<Product> vegan = await deps.productRepository
        .getProducts(const ProductFilter(diet: {DietTag.vegan, DietTag.lactoseFree}));
    expect(vegan.map((p) => p.name),
        containsAll(['Протеин растительный гороховый 750 г', 'Изотоник порошок 500 г']));
    expect(vegan.any((p) => p.name.startsWith('Протеин сывороточный')), isFalse);

    final Product whey = await productNamed('Протеин сывороточный 900 г');
    expect(whey.proteinPortion, (30, 24));
    final ProteinPlan plan = ProteinPlan.of(whey, 75, ProteinGoal.gain);
    expect(plan.dailyProtein, 135);
    expect(plan.portions, 2); // 45 г белка из протеина ≈ 2 порции
    expect(plan.days, 15); // 900 г / (2 × 30 г)
  });

  test('корзина: покупаем только отмеченное, остальное остаётся', () async {
    final User buyer = await login('maria@mail.kz', 'Maria123');
    final CartState cart = CartState(deps.cartRepository);
    await cart.setUser(buyer.id);
    final Product ball = await productNamed('Мяч волейбольный Mikasa V200W');
    final Product whey = await productNamed('Протеин сывороточный 900 г');
    await cart.add(ball);
    await cart.add(whey);
    expect(cart.selectedItems.length, 2);
    cart.toggle(cart.items.firstWhere((i) => i.product.id == whey.id));
    expect(cart.selectedItems.single.product.id, ball.id);
    expect(cart.selectedTotal, ball.price);
    await cart.removeItems(cart.selectedItems);
    expect(cart.items.single.product.id, whey.id);
    // Снятая галочка у оставшегося товара сохраняется, «Выбрать все» её ставит.
    expect(cart.isSelected(cart.items.single), isFalse);
    cart.selectAll(true);
    expect(cart.isSelected(cart.items.single), isTrue);
  });

  test('магазин: рейтинг и отзывы о товарах продавца', () async {
    final User seller = await login('budo@sport.kz', 'Seller123');
    final (double? rating, int count) = await deps.feedbackRepository.shopRating(seller.id);
    expect(count, greaterThan(0));
    expect(rating, inInclusiveRange(1, 5));
    final List<Review> reviews = await deps.feedbackRepository.getShopReviews(seller.id);
    expect(reviews.every((r) => r.productName != null), isTrue);
    final List<Product> own = await deps.productRepository
        .getProducts(const ProductFilter(ownGoods: true));
    expect(own.every((p) => p.sellerId == null), isTrue);
  });

  test('отзыв «наркоши…» отправляет товар продавца в очередь админу', () async {
    final User buyer = await login('maria@mail.kz', 'Maria123');
    final Product whey = await productNamed('Протеин сывороточный 900 г');
    await deps.feedbackRepository.saveReview(Review(
      userId: buyer.id!, productId: whey.id!, rating: 1,
      text: 'Наркошы эти задолбали уже здесь', createdAt: DateTime.now(),
    ));
    final Product checked = (await deps.productRepository.getProductById(whey.id!))!;
    expect(checked.moderation, 'flagged');
    expect((await deps.moderationRepository.reviewQueue()).any((p) => p.id == whey.id), isTrue);
    await deps.feedbackRepository.deleteReview(buyer.id!, whey.id!);
  });
}
