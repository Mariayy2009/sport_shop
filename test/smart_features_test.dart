import 'dart:io';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_shop/core/di/app_dependencies.dart';
import 'package:sport_shop/core/errors/app_exception.dart';
import 'package:sport_shop/data/database/app_database.dart';
import 'package:sport_shop/data/datasources/local/session_local_datasource.dart';
import 'package:sport_shop/services/assistant/ai_key_store.dart';
import 'package:sport_shop/services/assistant/assistant_engine.dart';
import 'package:sport_shop/services/assistant/configurable_assistant_engine.dart';
import 'package:sport_shop/services/assistant/gemini_assistant_engine.dart';
import 'package:sport_shop/services/assistant/local_assistant_engine.dart';
import 'package:sport_shop/models/chat_message.dart';
import 'package:sport_shop/models/enums.dart';
import 'package:sport_shop/models/exhibit.dart';
import 'package:sport_shop/models/product.dart';
import 'package:sport_shop/models/product_filter.dart';
import 'package:sport_shop/models/question.dart';
import 'package:sport_shop/models/review.dart';
import 'package:sport_shop/models/sport.dart';
import 'package:sport_shop/models/sport_kit.dart';
import 'package:sport_shop/models/user.dart';
import 'package:sport_shop/models/user_sizes.dart';
import 'package:sport_shop/services/media_storage.dart';
import 'package:sport_shop/services/size_advisor.dart';
import 'package:sport_shop/state/compare_state.dart';
import 'package:sport_shop/state/favorites_state.dart';
import 'package:sport_shop/state/profile_state.dart';
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
      aiKeyStore: InMemoryAiKeyStore(),
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

  group('Отзывы', () {
    test('отзыв доступен только после получения товара', () async {
      final (User user, _) = await maria();
      final Product delivered = await product('Шорты волейбольные');
      final Product inTransit = await product('Волейбольная форма');
      final Product never = await product('Гиря 8 кг');
      expect(await deps.feedbackRepository.hasPurchased(user.id!, delivered.id!), isTrue);
      expect(await deps.feedbackRepository.hasPurchased(user.id!, inTransit.id!), isFalse);
      expect(await deps.feedbackRepository.hasPurchased(user.id!, never.id!), isFalse);
    });

    test('рейтинг товара — средняя оценка отзывов', () async {
      final (User user, _) = await maria();
      final User ivan = (await deps.userRepository.findByEmail('ivan@mail.kz'))!;
      final Product shorts = await product('Шорты волейбольные');
      Review review(int userId, int rating) => Review(
            userId: userId,
            productId: shorts.id!,
            rating: rating,
            text: 'Текст отзыва',
            createdAt: DateTime(2026, 6, 1),
          );

      await deps.feedbackRepository.saveReview(review(user.id!, 5));
      await deps.feedbackRepository.saveReview(review(ivan.id!, 2));
      Product updated = await product('Шорты волейбольные');
      expect(updated.rating, 3.5);
      expect(updated.reviewsCount, 2);

      // Повторный отзыв заменяет прежний, а не добавляется.
      await deps.feedbackRepository.saveReview(review(ivan.id!, 4));
      updated = await product('Шорты волейбольные');
      expect(updated.rating, 4.5);
      expect(updated.reviewsCount, 2);

      final List<Review> reviews =
          await deps.feedbackRepository.getReviews(shorts.id!);
      expect(reviews.map((item) => item.authorName), containsAll(['Мария Г.', 'Иван П.']));
      expect((await deps.feedbackRepository.getReviewsByUser(user.id!))[shorts.id]!.rating, 5);

      await deps.feedbackRepository.deleteReview(ivan.id!, shorts.id!);
      expect((await product('Шорты волейбольные')).reviewsCount, 1);
    });
  });

  group('Вопросы о товаре', () {
    test('вопрос, ответ администратора и порядок в панели', () async {
      final (User user, _) = await maria();
      final Product ball = await product('Профессиональный мяч MIKASA');
      await deps.feedbackRepository.askQuestion(Question(
        productId: ball.id!,
        userId: user.id!,
        text: 'Это мяч для зала или для пляжа?',
        createdAt: DateTime(2026, 6, 2),
      ));

      Question asked =
          (await deps.feedbackRepository.getQuestions(ball.id!)).single;
      expect(asked.isAnswered, isFalse);
      // В панели администратора вопросы без ответа идут первыми.
      final List<Question> all = await deps.feedbackRepository.getAllQuestions();
      expect(all.first.isAnswered, isFalse);
      expect(all.last.isAnswered, isTrue);

      await deps.feedbackRepository.answerQuestion(asked.id!, 'Для зала.');
      asked = (await deps.feedbackRepository.getQuestions(ball.id!)).single;
      expect(asked.answer, 'Для зала.');
      expect(asked.answeredAt, isNotNull);

      await deps.feedbackRepository.deleteQuestion(asked.id!);
      expect(await deps.feedbackRepository.getQuestions(ball.id!), isEmpty);
    });
  });

  group('Фото пользователя', () {
    test('аватар сохраняется в профиле и удаляется', () async {
      final (User user, _) = await maria();
      final FakeMediaStorage storage = FakeMediaStorage();
      final ProfileState profile = ProfileState(deps.userRepository, storage);

      final User withAvatar = (await profile.pickAvatar(user, PhotoSource.gallery))!;
      expect(withAvatar.avatarPath, '/fake/avatar_1.jpg');
      expect((await deps.userRepository.findById(user.id!))!.avatarPath, isNotNull);

      final User cleared = await profile.removeAvatar(withAvatar);
      expect(cleared.avatarPath, isNull);
      expect(storage.deleted, contains('/fake/avatar_1.jpg'));
    });
  });

  group('Администратор', () {
    test('создание, изменение и удаление товара', () async {
      final Product source = await product('Гиря 8 кг');
      final Product created = await deps.productRepository.createProduct(Product(
        name: 'Гиря 12 кг',
        price: 9990,
        categoryId: source.categoryId,
        sportId: source.sportId,
        stock: 3,
        brand: 'Torneo',
      ));
      expect((await product('Гиря 12 кг')).brand, 'Torneo');

      await deps.productRepository.updateProduct(created.copyWith(stock: 0, price: 8990));
      final Product updated = await product('Гиря 12 кг');
      expect(updated.isAvailable, isFalse);
      expect(updated.price, 8990);

      await deps.productRepository.deleteProduct(created.id!);
      expect(await deps.productRepository.getProductById(created.id!), isNull);
    });

    test('товар из заказов удалить нельзя', () async {
      final Product ordered = await product('Наколенники волейбольные');
      expect(
        () => deps.productRepository.deleteProduct(ordered.id!),
        throwsA(isA<Exception>()),
      );
    });

    test('смена статуса открывает покупателю отзыв', () async {
      final (User user, _) = await maria();
      final Product uniform = await product('Волейбольная форма');
      expect(await deps.feedbackRepository.hasPurchased(user.id!, uniform.id!), isFalse);
      await deps.orderRepository.updateStatus(1019, OrderStatus.delivered);
      expect(await deps.feedbackRepository.hasPurchased(user.id!, uniform.id!), isTrue);
    });
  });

  group('ИИ-помощник: Gemini', () {
    Future<AssistantContext> context() async => AssistantContext(
          catalog: await deps.productRepository.getProducts(),
          sports: await deps.productRepository.getSports(),
        );

    AssistantEngine local() => LocalAssistantEngine(deps.recommendationRepository);

    test('ответ модели превращается в карточки; чужие id отбрасываются', () async {
      final AssistantContext ctx = await context();
      final Product shoes = ctx.catalog.firstWhere((p) => p.name == 'Кроссовки для бега');
      late Map<String, Object?> sent;
      late Map<String, String> headers;
      final GeminiAssistantEngine engine = GeminiAssistantEngine(
        apiKey: 'test-key',
        fallback: local(),
        client: MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, Object?>;
          headers = request.headers;
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'candidates': [
                {
                  'finishReason': 'STOP',
                  'content': {
                    'parts': [
                      {
                        'text': jsonEncode({
                          'message': 'Бери эти кроссовки.',
                          'picks': [
                            {'product_id': shoes.id, 'reason': 'Хорошая амортизация'},
                            {'product_id': 999999, 'reason': 'Такого товара нет'},
                          ],
                          'is_kit': false,
                          'suggestions': ['А подешевле?'],
                        }),
                      },
                    ],
                  },
                },
              ],
            })),
            200,
          );
        }),
      );

      final AssistantReply reply = await engine.reply(ctx, [
        ChatMessage(role: ChatRole.assistant, text: 'Привет!'),
        ChatMessage.user('Какие кроссовки взять для бега?'),
      ]);
      expect(reply.text, 'Бери эти кроссовки.');
      expect(reply.picks.single.product.id, shoes.id);
      expect(reply.suggestions, ['А подешевле?']);
      expect(headers['x-goog-api-key'], 'test-key');
      // Диалог для модели начинается с пользователя, каталог — в инструкции.
      final List<Object?> contents = sent['contents']! as List<Object?>;
      expect((contents.single! as Map)['role'], 'user');
      expect(jsonEncode(sent['systemInstruction']), contains('Кроссовки для бега'));
    });

    test('ошибки API: локальный ответ с причиной и текстом от Google', () async {
      final AssistantContext ctx = await context();
      for (final (int status, String hint) in const [
        (400, 'Ключ Gemini не принят: API key not valid'),
        (429, 'лимит'),
        (500, 'ошибку 500'),
      ]) {
        final GeminiAssistantEngine engine = GeminiAssistantEngine(
          apiKey: 'bad',
          fallback: local(),
          client: MockClient((request) async => http.Response(
                jsonEncode({'error': {'message': 'API key not valid'}}),
                status,
              )),
        );
        final AssistantReply reply =
            await engine.reply(ctx, [ChatMessage.user('Собери комплект для бега')]);
        expect(reply.text, contains(hint));
        expect(reply.picks, isNotEmpty);
      }
    });

    test('перегруженная модель: отвечает запасная', () async {
      final List<String> asked = [];
      final GeminiAssistantEngine engine = GeminiAssistantEngine(
        apiKey: 'key',
        fallback: local(),
        client: MockClient((request) async {
          asked.add(request.url.pathSegments.last);
          if (asked.length == 1) return http.Response('{}', 503);
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text': jsonEncode({
                          'message': 'Готово',
                          'picks': <Object>[],
                          'is_kit': false,
                          'suggestions': <String>[],
                        }),
                      },
                    ],
                  },
                },
              ],
            })),
            200,
          );
        }),
      );
      final AssistantReply reply =
          await engine.reply(await context(), [ChatMessage.user('Привет')]);
      expect(reply.text, 'Готово');
      expect(asked, [
        'gemini-flash-latest:generateContent',
        'gemini-flash-lite-latest:generateContent',
      ]);
    });

    test('схема не принята: повтор без схемы', () async {
      int calls = 0;
      final GeminiAssistantEngine engine = GeminiAssistantEngine(
        apiKey: 'key',
        fallback: local(),
        client: MockClient((request) async {
          calls++;
          final Map<String, Object?> config = (jsonDecode(request.body)
              as Map<String, Object?>)['generationConfig']! as Map<String, Object?>;
          if (config.containsKey('responseSchema')) {
            return http.Response(
              jsonEncode({'error': {'message': 'Invalid response_schema'}}),
              400,
            );
          }
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': '{"message":"Без схемы","picks":[],"is_kit":false,"suggestions":[]}'},
                    ],
                  },
                },
              ],
            })),
            200,
          );
        }),
      );
      final AssistantReply reply =
          await engine.reply(await context(), [ChatMessage.user('Привет')]);
      expect(reply.text, 'Без схемы');
      expect(calls, 2);
    });

    test('проверка ключа перед сохранением', () async {
      expect(
        await GeminiAssistantEngine.checkKey('ok',
            client: MockClient((request) async => http.Response('{}', 200))),
        isNull,
      );
      expect(
        await GeminiAssistantEngine.checkKey('bad',
            client: MockClient((request) async => http.Response(
                jsonEncode({'error': {'message': 'API key not valid'}}), 400))),
        contains('не принят'),
      );
      expect(
        await GeminiAssistantEngine.checkKey('x',
            client: MockClient((request) async => throw Exception('нет сети'))),
        contains('Нет связи'),
      );
    });

    test('движок выбирается по сохранённому ключу', () async {
      final InMemoryAiKeyStore store = InMemoryAiKeyStore();
      final ConfigurableAssistantEngine engine =
          ConfigurableAssistantEngine(local: local(), keyStore: store);
      expect(await engine.currentProvider(), AiProvider.local);
      await engine.setGeminiKey('  AIza-test-key  ');
      expect(await store.readGeminiKey(), 'AIza-test-key');
      expect(await engine.currentProvider(), AiProvider.gemini);
      await engine.setGeminiKey(null);
      expect(await engine.currentProvider(), AiProvider.local);
    });
  });

  group('Зал славы', () {
    test('экспонаты: создание, изменение, источник, удаление', () async {
      final Sport volleyball = await sport('Волейбол');
      // В демо-данных — 11 спортсменов Казахстана (первыми) и 23 экспоната
      // музея КНУС (№1 первым среди них).
      final List<Exhibit> seeded = await deps.exhibitRepository.getAll();
      expect(seeded.length, 34);
      expect(seeded.first.title, 'Михаил Шайдоров');
      expect(seeded.first.images, hasLength(2));
      expect(seeded.take(11).every((e) => e.source == ExhibitSource.kazakhstan), isTrue);
      final List<Exhibit> knus =
          seeded.where((e) => e.source == ExhibitSource.knus).toList();
      expect(knus, hasLength(23));
      expect(knus.first.sportTitle, 'Лыжные гонки');
      expect(seeded.every((item) => item.imageUrl != null && item.story != null), isTrue);
      // Все фото экспонатов есть в ресурсах приложения.
      for (final Exhibit exhibit in seeded) {
        for (final String image in exhibit.images) {
          expect(File(image).existsSync(), isTrue, reason: image);
        }
      }
      final Exhibit boxer =
          seeded.firstWhere((item) => item.title == 'Бекзат Саттарханов');
      expect(boxer.sportName, 'Бокс');
      expect(boxer.images, hasLength(2));
      final Exhibit karate =
          seeded.firstWhere((item) => item.athlete == 'Софья Берульцева');
      expect(karate.sportName, 'Карате');
      expect(karate.sportTitle, 'Каратэ (WKF)');

      await deps.exhibitRepository.save(Exhibit(
        title: 'Игровая майка',
        athlete: 'Тестовый Спортсмен',
        sportId: volleyball.id,
        year: '2020',
        story: 'Проверочная запись',
        createdAt: DateTime(2027, 1, 1),
      ));
      Exhibit saved = (await deps.exhibitRepository.getAll()).first;
      expect(saved.source, ExhibitSource.knus);
      expect(saved.sportName, 'Волейбол');

      await deps.exhibitRepository.save(Exhibit(
        id: saved.id,
        title: saved.title,
        athlete: saved.athlete,
        source: ExhibitSource.kazakhstan,
        createdAt: saved.createdAt,
      ));
      saved = (await deps.exhibitRepository.getById(saved.id!))!;
      expect(saved.source, ExhibitSource.kazakhstan);
      expect(saved.sportName, isNull);

      await deps.exhibitRepository.delete(saved.id!);
      expect(await deps.exhibitRepository.getById(saved.id!), isNull);
    });
  });
}

/// Хранилище фото без камеры и диска: выдаёт пути по порядку.
class FakeMediaStorage implements MediaStorage {
  FakeMediaStorage({this.cancel = false});

  final bool cancel;
  final List<String> deleted = [];
  int _counter = 0;

  @override
  Future<String?> pickAndSave({
    required int userId,
    required PhotoKind kind,
    required PhotoSource source,
  }) async =>
      cancel ? null : '/fake/${kind.name}_${++_counter}.jpg';

  @override
  Future<void> delete(String? path) async {
    if (path != null) deleted.add(path);
  }
}
