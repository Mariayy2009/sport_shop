import '../../data/database/app_database.dart';
import '../../data/datasources/local/cart_local_datasource.dart';
import '../../data/datasources/local/favorites_local_datasource.dart';
import '../../data/datasources/local/order_local_datasource.dart';
import '../../data/datasources/local/product_local_datasource.dart';
import '../../data/datasources/local/recommendation_local_datasource.dart';
import '../../data/datasources/local/session_local_datasource.dart';
import '../../data/datasources/local/user_local_datasource.dart';
import '../../data/repositories/cart_repository.dart';
import '../../data/repositories/exhibit_repository.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../data/repositories/feedback_repository.dart';
import '../../data/repositories/local_cart_repository.dart';
import '../../data/repositories/local_favorites_repository.dart';
import '../../data/repositories/local_feedback_repository.dart';
import '../../data/repositories/local_order_repository.dart';
import '../../data/repositories/local_product_repository.dart';
import '../../data/repositories/local_recommendation_repository.dart';
import '../../data/repositories/local_user_repository.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/datasources/local/shop_server_storage.dart';
import '../../data/repositories/switchable_product_repository.dart';
import '../../data/repositories/try_on_repository.dart';
import '../../data/repositories/recommendation_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../services/assistant/ai_key_store.dart';
import '../../services/assistant/assistant_service.dart';
import '../../services/assistant/claude_assistant_engine.dart';
import '../../services/assistant/configurable_assistant_engine.dart';
import '../../services/assistant/local_assistant_engine.dart';
import '../../services/auth_service.dart';
import '../../services/kit_service.dart';
import '../../services/media_storage.dart';
import '../../services/try_on/photo_try_on_service.dart';
import '../../services/recommendation_service.dart';

/// Сборка всех зависимостей приложения в одном месте.
///
/// Сейчас: AppDependencies.local — репозитории работают с SQLite.
/// В дипломе появится AppDependencies.api с Api*Repository
/// (REST API → PostgreSQL). Экраны и состояния менять не придётся:
/// они знают только абстрактные UserRepository, ProductRepository и т. д.
class AppDependencies {
  const AppDependencies._({
    required this.userRepository,
    required this.productRepository,
    required this.shopServerStorage,
    required this.orderRepository,
    required this.cartRepository,
    required this.recommendationRepository,
    required this.favoritesRepository,
    required this.feedbackRepository,
    required this.exhibitRepository,
    required this.tryOnRepository,
    required this.mediaStorage,
    required this.photoTryOnService,
    required this.authService,
    required this.recommendationService,
    required this.kitService,
    required this.assistantService,
    required this.assistantEngine,
  });

  factory AppDependencies.local(
    AppDatabase database, {
    SessionStorage? sessionStorage,
    AssistantAiConfig aiConfig = const AssistantAiConfig(),
    MediaStorage? mediaStorage,
    AiKeyStore? aiKeyStore,
    TryOnRepository? tryOnRepository,
    PhotoTryOnService? photoTryOnService,
    ShopServerStorage? shopServerStorage,
  }) {
    final UserRepository userRepository =
        LocalUserRepository(UserLocalDataSource(database));
    final RecommendationRepository recommendationRepository =
        LocalRecommendationRepository(RecommendationLocalDataSource(database));

    // Каталог: SQLite на телефоне или сервер магазина (PostgreSQL).
    final SwitchableProductRepository productRepository =
        SwitchableProductRepository(
      LocalProductRepository(ProductLocalDataSource(database)),
    );

    // Помощник: локальные правила работают всегда; если пользователь
    // ввёл ключ Gemini (или ключ задан при сборке), отвечает языковая
    // модель, а локальный движок остаётся запасным.
    final ConfigurableAssistantEngine assistantEngine =
        ConfigurableAssistantEngine(
      local: LocalAssistantEngine(recommendationRepository),
      keyStore: aiKeyStore ?? SharedPreferencesAiKeyStore(),
      claudeConfig: aiConfig,
    );

    return AppDependencies._(
      userRepository: userRepository,
      productRepository: productRepository,
      shopServerStorage:
          shopServerStorage ?? SharedPreferencesShopServerStorage(),
      orderRepository: LocalOrderRepository(OrderLocalDataSource(database)),
      cartRepository: LocalCartRepository(CartLocalDataSource(database)),
      recommendationRepository: recommendationRepository,
      favoritesRepository:
          LocalFavoritesRepository(FavoritesLocalDataSource(database)),
      feedbackRepository: LocalFeedbackRepository(database),
      exhibitRepository: LocalExhibitRepository(database),
      tryOnRepository: tryOnRepository ?? LocalTryOnRepository(),
      mediaStorage: mediaStorage ?? DeviceMediaStorage(),
      photoTryOnService: photoTryOnService ?? PhotoTryOnService(),
      authService: AuthService(
        userRepository: userRepository,
        sessionStorage: sessionStorage ?? SharedPreferencesSessionStorage(),
      ),
      recommendationService: RecommendationService(
        LocalRecommendationEngine(recommendationRepository),
      ),
      kitService: KitService(recommendationRepository),
      assistantService: AssistantService(assistantEngine, productRepository),
      assistantEngine: assistantEngine,
    );
  }

  final UserRepository userRepository;
  final SwitchableProductRepository productRepository;

  /// Адрес сервера магазина, если пользователь его подключил.
  final ShopServerStorage shopServerStorage;
  final OrderRepository orderRepository;
  final CartRepository cartRepository;
  final RecommendationRepository recommendationRepository;
  final FavoritesRepository favoritesRepository;
  final FeedbackRepository feedbackRepository;
  final ExhibitRepository exhibitRepository;
  final TryOnRepository tryOnRepository;
  final MediaStorage mediaStorage;
  final PhotoTryOnService photoTryOnService;
  final AuthService authService;
  final RecommendationService recommendationService;
  final KitService kitService;
  final AssistantService assistantService;

  /// Настройки ИИ: какая модель отвечает, ключ Gemini.
  final ConfigurableAssistantEngine assistantEngine;
}
