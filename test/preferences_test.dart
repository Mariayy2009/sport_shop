import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sport_shop/data/datasources/local/product_local_datasource.dart';
import 'package:sport_shop/data/database/app_database.dart';
import 'package:sport_shop/data/repositories/local_product_repository.dart';
import 'package:sport_shop/models/enums.dart';
import 'package:sport_shop/models/product.dart';
import 'package:sport_shop/models/shopping_preferences.dart';
import 'package:sport_shop/models/sport.dart';
import 'package:sport_shop/models/user.dart';
import 'package:sport_shop/models/user_sizes.dart';
import 'package:sport_shop/services/assistant/assistant_engine.dart';
import 'package:sport_shop/services/assistant/claude_assistant_engine.dart';
import 'package:sport_shop/services/preferences/preference_matcher.dart';
import 'package:sport_shop/services/preferences/style_catalog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late List<Product> catalog;
  late List<Sport> sports;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final LocalProductRepository repository = LocalProductRepository(
      ProductLocalDataSource(AppDatabase.withPath(inMemoryDatabasePath)),
    );
    catalog = await repository.getProducts();
    sports = [
      for (final Sport s in await repository.getSports())
        if (!s.isUniversal) s,
    ];
  });

  test('названия цветов по цвету вещи', () {
    expect(PreferenceMatcher.colorKeyOf(const Color(0xFFE85A9B)), 'pink');
    expect(PreferenceMatcher.colorKeyOf(const Color(0xFF151517)), 'black');
    expect(PreferenceMatcher.colorKeyOf(const Color(0xFFF3F1EB)), 'white');
    expect(PreferenceMatcher.colorKeyOf(const Color(0xFF2849B8)), 'blue');
    expect(PreferenceMatcher.colorKeyOf(const Color(0xFFF2C21A)), 'yellow');
    expect(PreferenceMatcher.colorKeyOf(const Color(0xFF1FC4B6)), 'lightblue');
  });

  test('у каждого вида спорта каталога есть позиции, и всем им есть товары', () {
    for (final Sport sport in sports) {
      final List<SportPosition> positions = StyleCatalog.positionsFor(sport.name);
      expect(positions, isNotEmpty, reason: sport.name);
      for (final SportPosition position in positions) {
        for (final PositionNeed need in position.needs) {
          expect(catalog.any((p) => need.matches(p.name)), isTrue,
              reason: '${sport.name} / ${position.title}: ${need.keywords}');
        }
      }
    }
  });

  test('либеро + розовый + хлопок: сначала то, что нужно либеро', () {
    const ShoppingPreferences preferences = ShoppingPreferences(
      colors: {'pink'},
      position: 'libero',
      materials: {'cotton'},
    );
    final Sport volleyball = sports.firstWhere((s) => s.name == 'Волейбол');
    final Map<int, String> colors = {
      for (final Product p in catalog)
        if (p.name == 'Наколенники ASICS') p.id!: 'pink',
    };
    final List<PreferenceMatch> matches = const PreferenceMatcher().rank(
      catalog,
      preferences,
      sportId: volleyball.id,
      sportName: 'Волейбол',
      colors: colors,
    );
    // Розовые наколенники — и для либеро, и в любимом цвете.
    expect(matches.first.product.name, 'Наколенники ASICS');
    expect(matches.first.reasons.first, startsWith('Либеро:'));
    expect(matches.first.inColor, isTrue);
    // Хлопковое кимоно попало по материалу, хотя это не волейбол.
    final PreferenceMatch kimono =
        matches.firstWhere((m) => m.product.name == 'Кимоно для карате');
    expect(kimono.inMaterial, isTrue);
    expect(kimono.forPosition, isFalse);
  });

  test('анкета сохраняется и читается', () {
    const ShoppingPreferences p = ShoppingPreferences(
      colors: {'black', 'pink'},
      position: 'goalkeeper',
      materials: {'synthetic'},
    );
    final ShoppingPreferences back = ShoppingPreferences.decode(p.encode());
    expect(back.colors, {'black', 'pink'});
    expect(back.position, 'goalkeeper');
    expect(ShoppingPreferences.decode('не json').isEmpty, isTrue);
  });

  test('ИИ-помощник получает анкету в профиле покупателя', () {
    final Sport football = sports.firstWhere((s) => s.name == 'Футбол');
    final String text = ClaudeAssistantEngine.profileText(AssistantContext(
      catalog: catalog,
      sports: sports,
      user: User(
        id: 1,
        email: 'm@mail.kz',
        passwordHash: 'x',
        role: UserRole.values.first,
        firstName: 'Мария',
        createdAt: DateTime(2026),
      ),
      sizes: UserSizes(userId: 1, sportId: football.id),
      preferences: const ShoppingPreferences(
        colors: {'pink'},
        position: 'goalkeeper',
        materials: {'cotton'},
      ),
    ));
    expect(text, contains('позиция: Вратарь'));
    expect(text, contains('любимые цвета: розовый'));
    expect(text, contains('материалы: хлопок'));
  });
}
