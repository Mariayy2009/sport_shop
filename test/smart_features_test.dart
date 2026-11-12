import 'package:flutter_test/flutter_test.dart';
import 'package:sport_shop/core/di/app_dependencies.dart';
import 'package:sport_shop/core/errors/app_exception.dart';
import 'package:sport_shop/data/database/app_database.dart';
import 'package:sport_shop/data/datasources/local/session_local_datasource.dart';
import 'package:sport_shop/models/chat_message.dart';
import 'package:sport_shop/models/enums.dart';
import 'package:sport_shop/models/outfit.dart';
import 'package:sport_shop/models/product.dart';
import 'package:sport_shop/models/product_filter.dart';
import 'package:sport_shop/models/sport.dart';
import 'package:sport_shop/models/sport_kit.dart';
import 'package:sport_shop/models/user.dart';
import 'package:sport_shop/models/user_sizes.dart';
import 'package:sport_shop/services/size_advisor.dart';
import 'package:sport_shop/state/compare_state.dart';
import 'package:sport_shop/state/favorites_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Умные функции: подбор размера, комплекты, избранное, сравнение,
/// ИИ-помощник (локальный движок) — на настоящей SQLite в памяти.
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
    );
    await database.database;
  });

  tearDown(() => database.close());

  Future<Product> product(String name) async {
    final List<Product> all = await deps.productRepository.getProducts();
    return all.firstWhere((item) => item.name == name);
  }

  Future<Sport> sport(String name) async {
    final List<Sport> sports = await deps.productRepository.getSports();
    return sports.firstWhere((item) => item.name == name);
  }

  Future<(User, UserSizes)> maria() async {
    final User user = (await deps.userRepository.findByEmail('maria@mail.kz'))!;
    return (user, (await deps.userRepository.getSizes(user.id!))!);
  }

  test('у товаров есть бренд, материал и рейтинг', () async {
    final Product shoes = await product('Кроссовки для волейбола');
    expect(shoes.brand, 'Asics');
    expect(shoes.material, isNotEmpty);
    expect(shoes.rating, 4.8);
  });

  group('Умный подбор размера', () {
    const SizeAdvisor advisor = SizeAdvisor();
    const UserSizes sizes = UserSizes(
      userId: 1,
      height: 160,
      weight: 60,
      clothingSize: 'S',
      shoeSize: 38,
    );

    test('размер одежды по росту и весу — больший из двух', () {
      expect(advisor.clothingSizeByBody(height: 160, weight: 60), 'M');
      expect(advisor.clothingSizeByBody(height: 185, weight: 70), 'XXL');
      expect(advisor.clothingSizeByBody(height: 150, weight: 45), 'XS');
      expect(advisor.clothingSizeByBody(), isNull);
    });

    test('одежда: размер из профиля, мерки — как альтернатива', () async {
      final SizeAdvice advice =
          advisor.advise(await product('Волейбольная форма'), sizes)!;
      expect(advice.size, 'S');
      expect(advice.alternative, 'M');
      expect(advice.confidence, SizeConfidence.medium);
    });

    test('обувь: размер из профиля', () async {
      final SizeAdvice advice =
          advisor.advise(await product('Кроссовки для волейбола'), sizes)!;
      expect(advice.size, '38');
      expect(advice.confidence, SizeConfidence.high);
    });

    test('обувь: нет нужного размера — ближайший', () async {
      // У бутс размеры начинаются с 38.
      final SizeAdvice advice = advisor.advise(
        await product('Бутсы футбольные'),
        const UserSizes(userId: 1, shoeSize: 36),
      )!;
      expect(advice.size, '38');
      expect(advice.confidence, SizeConfidence.medium);
    });

    test('защита S–L: XS заменяется ближайшим доступным', () async {
      final SizeAdvice advice = advisor.advise(
        await product('Наколенники волейбольные'),
        const UserSizes(userId: 1, clothingSize: 'XS'),
      )!;
      expect(advice.size, 'S');
    });

    test('кимоно подбирается по росту, перчатки — по весу', () async {
      expect(advisor.advise(await product('Кимоно для карате'), sizes)!.size, '160');
      expect(advisor.advise(await product('Боксёрские перчатки'), sizes)!.size, '12oz');
    });

    test('товар без размера и пустой профиль — совета нет', () async {
      expect(advisor.advise(await product('Гиря 8 кг'), sizes), isNull);
      expect(advisor.advise(await product('Волейбольная форма'), null), isNull);
    });
  });

  group('Комплекты', () {
    test('комплект для волейбола с размерами из профиля', () async {
      final (_, UserSizes sizes) = await maria();
      final SportKit kit = await deps.kitService.buildKit(
        sport: await sport('Волейбол'),
        level: SportLevel.experienced,
        sizes: sizes,
      );
      expect(kit.mandatory.map((item) => item.product.name), containsAll([
        'Волейбольная форма',
        'Наколенники волейбольные',
        'Кроссовки для волейбола',
      ]));
      expect(kit.extras, isNotEmpty);
      expect(kit.fullPrice, greaterThan(kit.basePrice));
      final KitItem shoes = kit.items
          .firstWhere((item) => item.product.name == 'Кроссовки для волейбола');
      expect(shoes.size, '38');
      final KitItem uniform =
          kit.items.firstWhere((item) => item.product.name == 'Волейбольная форма');
      expect(uniform.size, 'S');
    });
  });

  group('Избранное', () {
    test('добавление, удаление и раздельные списки пользователей', () async {
      final (User user, _) = await maria();
      final FavoritesState favorites = FavoritesState(deps.favoritesRepository);
      await favorites.setUser(user.id);
      final Product ball = await product('Профессиональный мяч MIKASA');

      expect(await favorites.toggle(ball), isTrue);
      expect(favorites.contains(ball.id), isTrue);

      // Другой пользователь не видит чужое избранное.
      final User ivan = (await deps.userRepository.findByEmail('ivan@mail.kz'))!;
      await favorites.setUser(ivan.id);
      expect(favorites.isEmpty, isTrue);

      // Избранное сохранилось в базе.
      await favorites.setUser(user.id);
      expect(favorites.items.single.name, ball.name);
      expect(await favorites.toggle(ball), isFalse);
      expect(favorites.isEmpty, isTrue);
    });

    test('гость не может добавить в избранное', () async {
      final FavoritesState favorites = FavoritesState(deps.favoritesRepository);
      expect(
        () async => favorites.toggle(await product('Гиря 8 кг')),
        throwsA(isA<AppException>()),
      );
    });
  });

  test('Сравнение: не больше четырёх товаров', () async {
    final CompareState compare = CompareState();
    final List<Product> all = await deps.productRepository.getProducts();
    for (final Product item in all.take(CompareState.maxItems)) {
      expect(compare.toggle(item), isTrue);
    }
    expect(() => compare.toggle(all[CompareState.maxItems]), throwsA(isA<AppException>()));
    expect(compare.toggle(all.first), isFalse);
    expect(compare.count, CompareState.maxItems - 1);
  });

  group('Примерочная', () {
    test('тип вещи определяется по товару', () async {
      expect(Outfit.kindOf(await product('Волейбольная форма')), WearKind.set);
      expect(Outfit.kindOf(await product('Кроссовки для бега')), WearKind.shoes);
      expect(Outfit.kindOf(await product('Тайтсы беговые')), WearKind.pants);
      expect(Outfit.kindOf(await product('Наколенники волейбольные')), WearKind.knee);
      expect(Outfit.kindOf(await product('Гиря 8 кг')), isNull);
    });
  });

  group('ИИ-помощник (локальный движок)', () {
    Future<AssistantReply> ask(
      List<String> questions, {
      bool withProfile = true,
    }) async {
      final (User user, UserSizes sizes) = await maria();
      final List<ChatMessage> history = [];
      late AssistantReply reply;
      for (final String question in questions) {
        history.add(ChatMessage.user(question));
        reply = await deps.assistantService.ask(
          history: history,
          user: withProfile ? user : null,
          sizes: withProfile ? sizes : null,
        );
        history.add(ChatMessage.fromReply(reply));
      }
      return reply;
    }

    test('собирает комплект по виду спорта из профиля', () async {
      final AssistantReply reply = await ask(['Собери мне комплект']);
      expect(reply.isKit, isTrue);
      expect(reply.picks.map((pick) => pick.product.sportName),
          everyElement(anyOf('Волейбол', 'Фитнес')));
      final ProductPick shoes = reply.picks
          .firstWhere((pick) => pick.product.name == 'Кроссовки для волейбола');
      expect(shoes.size, '38');
      expect(shoes.reason, contains('Основа комплекта'));
    });

    test('учитывает вид спорта, уровень и бюджет из вопроса', () async {
      final AssistantReply reply =
          await ask(['Собери комплект для бега для новичка до 60 тыс']);
      expect(reply.isKit, isTrue);
      expect(reply.picks.map((pick) => pick.product.name),
          containsAll(['Кроссовки для бега', 'Беговая футболка']));
      expect(reply.text, contains('60'));
    });

    test('ищет товары категории в бюджете', () async {
      final AssistantReply reply = await ask(['Покажи кроссовки до 25 000 тенге']);
      expect(reply.picks, isNotEmpty);
      for (final ProductPick pick in reply.picks) {
        expect(pick.product.categoryName, 'Обувь');
        expect(pick.product.price, lessThanOrEqualTo(25000));
      }
    });

    test('сравнивает товары и объясняет выбор', () async {
      final AssistantReply reply = await ask(['Сравни обувь для бега и для зала']);
      expect(reply.picks.length, greaterThanOrEqualTo(2));
      expect(reply.text, contains('рейтинг'));
    });

    test('подсказывает размер по профилю', () async {
      final AssistantReply reply =
          await ask(['Какой размер кроссовок для волейбола мне нужен?']);
      expect(reply.picks.first.product.name, 'Кроссовки для волейбола');
      expect(reply.picks.first.size, '38');
    });

    test('помнит вид спорта из прошлых сообщений', () async {
      final AssistantReply reply =
          await ask(['Хочу заняться йогой', 'Что купить до 10 тыс?']);
      expect(reply.picks, isNotEmpty);
      expect(reply.picks.map((pick) => pick.product.sportName), everyElement('Йога'));
    });

    test('без профиля и вида спорта задаёт уточняющий вопрос', () async {
      final AssistantReply reply = await ask(['Что посоветуешь?'], withProfile: false);
      expect(reply.picks, isEmpty);
      expect(reply.suggestions, isNotEmpty);
    });

    test('советует только товары из каталога', () async {
      final Set<int?> catalogIds = {
        for (final Product item
            in await deps.productRepository.getProducts(const ProductFilter()))
          item.id,
      };
      for (final String question in const [
        'Собери комплект для футбола',
        'Недорогая защита для бокса',
        'Что лучше для плавания?',
      ]) {
        final AssistantReply reply = await ask([question]);
        expect(reply.picks.map((pick) => pick.product.id), everyElement(isIn(catalogIds)));
      }
    });
  });
}
