import 'package:flutter_test/flutter_test.dart';
import 'package:sport_shop/core/di/app_dependencies.dart';
import 'package:sport_shop/data/database/app_database.dart';
import 'package:sport_shop/data/datasources/local/session_local_datasource.dart';
import 'package:sport_shop/main.dart';
import 'package:sport_shop/state/app_states.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  testWidgets('Гость видит нижнюю навигацию и приглашение войти',
      (WidgetTester tester) async {
    final AppDependencies dependencies = AppDependencies.local(
      AppDatabase.withPath(inMemoryDatabasePath),
      sessionStorage: InMemorySessionStorage(),
    );

    await tester.pumpWidget(SportShopApp(
      dependencies: dependencies,
      states: AppStates.create(dependencies),
    ));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Catalog'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pump();

    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Регистрация'), findsOneWidget);
  });
}
