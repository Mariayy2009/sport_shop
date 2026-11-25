import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sport_shop/core/di/app_dependencies.dart';
import 'package:sport_shop/core/routes/app_routes.dart';
import 'package:sport_shop/data/database/app_database.dart';
import 'package:sport_shop/data/datasources/local/session_local_datasource.dart';
import 'package:sport_shop/data/datasources/local/shop_server_storage.dart';
import 'package:sport_shop/data/repositories/preferences_repository.dart';
import 'package:sport_shop/data/repositories/try_on_repository.dart';
import 'package:sport_shop/main.dart';
import 'package:sport_shop/models/product.dart';
import 'package:sport_shop/services/assistant/ai_key_store.dart';
import 'package:sport_shop/state/app_states.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets('оформление заказа: поля доставки и промокод на месте, без ошибок',
      (WidgetTester tester) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final AppDependencies deps = AppDependencies.local(
      AppDatabase.withPath(inMemoryDatabasePath),
      sessionStorage: InMemorySessionStorage(),
      aiKeyStore: InMemoryAiKeyStore(),
      tryOnRepository: InMemoryTryOnRepository(),
      shopServerStorage: InMemoryShopServerStorage(),
      preferencesRepository: InMemoryPreferencesRepository(),
    );
    final AppStates states = AppStates.create(deps);
    await tester.runAsync(() async {
      await states.init();
      await states.auth.login(
        email: 'maria@mail.kz',
        password: 'Maria123',
        rememberMe: false,
      );
      final Product ball = (await deps.productRepository.getProducts())
          .firstWhere((p) => p.name.contains('Mikasa'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await states.cart.add(ball);
    });

    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SportShopApp(dependencies: deps, states: states));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pushNamed(AppRoutes.checkout);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('Промокод'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Применить промокод'),
      300,
      scrollable: find
          .descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable))
          .first,
    );
    expect(find.text('Применить промокод'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(TextFormField), findsWidgets);
    // Главный экран под оформлением дочитывает базу — даём ему закончить.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
    states.notifications.dispose();
    states.sellerBadges.dispose();
  });
}
