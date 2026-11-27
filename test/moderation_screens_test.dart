import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sport_shop/core/di/app_dependencies.dart';
import 'package:sport_shop/core/routes/app_routes.dart';
import 'package:sport_shop/data/database/app_database.dart';
import 'package:sport_shop/data/datasources/local/session_local_datasource.dart';
import 'package:sport_shop/data/datasources/local/shop_server_storage.dart';
import 'package:sport_shop/data/repositories/moderation_repository.dart';
import 'package:sport_shop/data/repositories/preferences_repository.dart';
import 'package:sport_shop/data/repositories/try_on_repository.dart';
import 'package:sport_shop/main.dart';
import 'package:sport_shop/models/user.dart';
import 'package:sport_shop/screens/admin/admin_sellers_screen.dart';
import 'package:sport_shop/services/assistant/ai_key_store.dart';
import 'package:sport_shop/state/app_states.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDependencies deps;
  late AppStates states;

  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    deps = AppDependencies.local(
      AppDatabase.withPath(inMemoryDatabasePath),
      sessionStorage: InMemorySessionStorage(),
      aiKeyStore: InMemoryAiKeyStore(),
      tryOnRepository: InMemoryTryOnRepository(),
      shopServerStorage: InMemoryShopServerStorage(),
      preferencesRepository: InMemoryPreferencesRepository(),
    );
    states = AppStates.create(deps);
  });

  Future<void> finish(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
    states.notifications.dispose();
    states.sellerBadges.dispose();
  }

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('администратор: продавцы, апелляция и окно удаления без ошибок',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await states.init();
      final User seller = await deps.authService
          .login(email: 'budo@sport.kz', password: 'Seller123', rememberMe: false);
      await deps.moderationRepository.freezeSeller(seller.id!, 'Жалобы на подделки');
      await deps.moderationRepository.submitAppeal(seller.id!, 'Мы всё исправили');
      await states.auth.login(email: 'admin@sport.kz', password: 'Admin123', rememberMe: false);
    });
    await tester.pumpWidget(SportShopApp(dependencies: deps, states: states));
    // Вкладка автопроверки открывается без ошибок.
    await tester.tap(find.text('Модерация'));
    await settle(tester);
    expect(find.text('Проверить весь каталог'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Продавцы'));
    await settle(tester);
    expect(find.text('Апелляции (1)'), findsOneWidget);
    expect(find.text('Заморожен'), findsOneWidget);
    expect(find.text('Разморозить'), findsOneWidget);

    await tester.tap(find.text('Удалить').first);
    await settle(tester);
    expect(find.byType(DeleteSellerSheet), findsOneWidget);
    expect(find.text('Удалить магазин'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('продавец: замороженный кабинет с кнопкой апелляции', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await states.init();
      final User seller = await states.auth
          .login(email: 'sportlife@sport.kz', password: 'Seller123', rememberMe: false);
      await deps.moderationRepository.freezeSeller(seller.id!, 'Жалобы на сроки годности');
      await states.sellerBadges.refresh();
    });
    expect(states.sellerBadges.status, SellerStatus.frozen);
    await tester.pumpWidget(SportShopApp(dependencies: deps, states: states));
    await tester.tap(find.text('Кабинет'));
    await settle(tester);
    expect(find.text('Магазин заморожен'), findsOneWidget);
    expect(find.text('Подать апелляцию'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('покупатель: каталог с вариантами, магазин, корзина с галочками', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await states.init();
      await states.auth.login(email: 'maria@mail.kz', password: 'Maria123', rememberMe: false);
      final all = await deps.productRepository.getProducts();
      // Магазины продавцов заморожены предыдущими тестами — берём товары SPORT.
      final own = all.where((p) => p.sellerId == null && !p.requiresSize).toList();
      await states.cart.add(own[0]);
      await states.cart.add(own[1]);
    });
    await tester.pumpWidget(SportShopApp(dependencies: deps, states: states));
    await tester.tap(find.text('Каталог').last);
    await settle(tester);
    expect(find.textContaining('Найдено:'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Корзина').last);
    await settle(tester);
    expect(find.text('Выбрать все'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).at(1));
    await settle(tester);
    expect(find.textContaining('Оформить заказ (1 шт.)'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first)
        .pushNamed(AppRoutes.shop, arguments: const ShopArgs(null, 'SPORT'));
    await settle(tester);
    expect(find.textContaining('Официальный магазин площадки'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });
}
