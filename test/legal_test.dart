import 'package:flutter_test/flutter_test.dart';
import 'package:sport_shop/core/di/app_dependencies.dart';
import 'package:sport_shop/core/errors/app_exception.dart';
import 'package:sport_shop/core/utils/validators.dart';
import 'package:sport_shop/data/database/app_database.dart';
import 'package:sport_shop/data/datasources/local/session_local_datasource.dart';
import 'package:sport_shop/data/repositories/moderation_repository.dart';
import 'package:sport_shop/data/repositories/preferences_repository.dart';
import 'package:sport_shop/models/item_options.dart';
import 'package:sport_shop/models/product.dart';
import 'package:sport_shop/models/product_filter.dart';
import 'package:sport_shop/models/user.dart';
import 'package:sport_shop/screens/catalog/catalog_screen.dart';
import 'package:sport_shop/services/assistant/ai_key_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// ИИН/БИН с верной контрольной цифрой из 11 первых цифр (для тестов).
String withChecksum(String eleven) {
  for (int last = 0; last <= 9; last++) {
    if (Validators.hasValidChecksum('$eleven$last')) return '$eleven$last';
  }
  throw StateError('нет контрольной цифры для $eleven');
}

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

  test('ИИН и БИН: длина, дата, тип организации, контрольная цифра', () {
    final String iin = withChecksum('95031540012');
    expect(Validators.iin(iin, bin: false), isNull);
    expect(Validators.iin('12345', bin: false), contains('12 цифр'));
    final String wrong = iin.substring(0, 11) + ((int.parse(iin[11]) + 1) % 10).toString();
    expect(Validators.iin(wrong, bin: false), contains('контрольная'));
    expect(Validators.iin(withChecksum('95139940012'), bin: false), contains('дата'));
    final String bin = withChecksum('26114012345');
    expect(Validators.iin(bin, bin: true), isNull);
    expect(Validators.iin(withChecksum('26111012345'), bin: true), contains('тип организации'));
  });

  test('магазин SPORT — продавец; у всех товаров есть продавец', () async {
    final List<Product> all = await deps.productRepository.getProducts();
    expect(all.every((p) => p.sellerId != null), isTrue);
    expect(all.where((p) => p.sellerName == 'SPORT'), isNotEmpty);
    final User sport = await deps.authService
        .login(email: 'sport@sport.kz', password: 'Seller123', rememberMe: false);
    expect(sport.isSeller, isTrue);
    expect(sport.shopName, 'SPORT');
  });

  test('покупатель открывает магазин с ИИН и согласиями; материалы для полиции', () async {
    final User buyer = await deps.authService
        .login(email: 'maria@mail.kz', password: 'Maria123', rememberMe: false);
    final ModerationRepository moderation = deps.moderationRepository;
    final SellerLegal legal = SellerLegal(
      legalForm: 'ИП',
      iin: withChecksum('95031540012'),
      legalName: 'Габдулина Мария',
      phone: '+7 708 777 55 55',
      address: 'г. Астана, ул. Примерная, 1',
      agreedAt: DateTime.now(),
      rulesVersion: '1.0',
    );
    await moderation.openShop(buyer.id!, 'Мария Спорт', legal);
    expect(() => moderation.openShop(buyer.id!, 'мария спорт', legal), throwsA(isA<AppException>()));
    final User seller = (await deps.userRepository.findById(buyer.id!))!;
    expect(seller.isSeller, isTrue);
    expect((await moderation.legalOf(buyer.id!)).complete, isTrue);

    // Демо-продавец без данных — выставлять товары не может.
    final User budo = await deps.authService
        .login(email: 'budo@sport.kz', password: 'Seller123', rememberMe: false);
    expect((await moderation.legalOf(budo.id!)).complete, isFalse);

    final List<Product> mine = await deps.productRepository
        .getProducts(ProductFilter(sellerId: budo.id, includeBlocked: true));
    await moderation.blockProduct(mine.first, WarningReason.fraud, text: 'Подозрение на сбыт');
    final String report =
        await moderation.buildLawReport(sellerId: budo.id!, productId: mine.first.id);
    expect(report, contains('Budo Pro'));
    expect(report, contains(mine.first.name));
    expect(report, contains('Подозрение на мошенничество'));
    await moderation.saveLawReport(sellerId: budo.id!, productId: mine.first.id, text: report);
    expect(await moderation.lawReportsCount(budo.id!), 1);
    await moderation.unblockProduct(mine.first.id!);
  });

  test('каталог «Рекомендуем»: варианты одного товара не стоят рядом', () async {
    final List<Product> all = await deps.productRepository.getProducts();
    final List<(Product, ProductVariant?)> cards = [
      for (final Product p in all)
        if (p.variants.isEmpty) (p, null) else for (final v in p.variants) (p, v),
    ];
    final mixed = CatalogMix.mix(cards, seed: 7);
    expect(mixed.length, cards.length);
    int neighbours = 0;
    for (int i = 1; i < mixed.length; i++) {
      if (mixed[i].$1.id == mixed[i - 1].$1.id) neighbours++;
    }
    expect(neighbours, 0);
  });
}
