import 'package:flutter_test/flutter_test.dart';
import 'package:sport_shop/core/di/app_dependencies.dart';
import 'package:sport_shop/data/database/app_database.dart';
import 'package:sport_shop/data/datasources/local/session_local_datasource.dart';
import 'package:sport_shop/data/repositories/try_on_repository.dart';
import 'package:sport_shop/services/assistant/ai_key_store.dart';
import 'package:sport_shop/main.dart';
import 'package:sport_shop/state/app_states.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  testWidgets('Гость видит нижнюю навигацию и приглашение войти',
      (WidgetTester tester) async {
    final AppDependencies dependencies = AppDependencies.local(
      AppDatabase.withPath(inMemoryDatabasePath),
      sessionStorage: InMemorySessionStorage(),
      aiKeyStore: InMemoryAiKeyStore(),
      tryOnRepository: InMemoryTryOnRepository(),
    );

    await tester.pumpWidget(SportShopApp(
      dependencies: dependencies,
      states: AppStates.create(dependencies),
    ));

    expect(find.text('Главная'), findsOneWidget);
    expect(find.text('Каталог'), findsOneWidget);
    expect(find.text('Профиль'), findsOneWidget);

    await tester.tap(find.text('Профиль'));
    await tester.pump();

    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Регистрация'), findsOneWidget);
  });
}
