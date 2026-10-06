import 'package:flutter_test/flutter_test.dart';
import 'package:sport_shop/main.dart';

void main() {
  testWidgets('Приложение запускается', (WidgetTester tester) async {
    await tester.pumpWidget(const SportShopApp());
    expect(find.text('Этап 1: структура проекта'), findsOneWidget);
  });
}
