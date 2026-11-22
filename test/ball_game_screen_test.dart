import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sport_shop/screens/games/ball_game_screen.dart';

void main() {
  testWidgets('игра без камеры: подбросить мяч, режимы, мяч падает', (tester) async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: BallGameScreen()));
    // Загрузка картинок мячей и рекордов идёт по-настоящему асинхронно.
    for (int i = 0; i < 30 && find.text('Запускаю камеру…').evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.textContaining('отбивай мяч мышкой'), findsOneWidget);
    expect(find.text('Подбросить мяч'), findsOneWidget);

    await tester.tap(find.text('Волейбол: нижний приём'));
    await tester.pump();
    await tester.tap(find.text('Подбросить мяч'));
    for (int i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Никто не отбивал — мяч упал.
    expect(find.textContaining('Мяч упал'), findsOneWidget);
    expect(find.text('Ещё раз'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}
