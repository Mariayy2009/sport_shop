import '../../data/database/app_database.dart';
import '../../data/datasources/local/cart_local_datasource.dart';
import '../../data/datasources/local/favorites_local_datasource.dart';
import '../../data/datasources/local/order_local_datasource.dart';
import '../../data/datasources/local/product_local_datasource.dart';
import '../../data/datasources/local/recommendation_local_datasource.dart';
import '../../data/datasources/local/session_local_datasource.dart';
import '../../data/datasources/local/user_local_datasource.dart';
import '../../data/repositories/cart_repository.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../data/repositories/feedback_repository.dart';
import '../../data/repositories/fitting_repository.dart';
import '../../data/repositories/local_cart_repository.dart';
import '../../data/repositories/local_favorites_repository.dart';
import '../../data/repositories/local_feedback_repository.dart';
import '../../data/repositories/local_order_repository.dart';
import '../../data/repositories/local_product_repository.dart';
import '../../data/repositories/local_recommendation_repository.dart';
import '../../data/repositories/local_user_repository.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/recommendation_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../services/assistant/assistant_engine.dart';
import '../../services/assistant/assistant_service.dart';
import '../../services/assistant/claude_assistant_engine.dart';
import '../../services/assistant/local_assistant_engine.dart';
import '../../services/auth_service.dart';
import '../../services/kit_service.dart';
import '../../services/media_storage.dart';
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
    required this.orderRepository,
    required this.cartRepository,
    required this.recommendationRepository,
    required this.favoritesRepository,
    required this.feedbackRepository,
    required this.fittingRepository,
    required this.mediaStorage,
    required this.authService,
    required this.recommendationService,
    required this.kitService,
    required this.assistantService,
  });

  factory AppDependencies.local(
    AppDatabase database, {
    SessionStorage? sessionStorage,
    AssistantAiConfig aiConfig = const AssistantAiConfig(),
    MediaStorage? mediaStorage,
  }) {
    final UserRepository userRepository =
        LocalUserRepository(UserLocalDataSource(database));
    final RecommendationRepository recommendationRepository =
        LocalRecommendationRepository(RecommendationLocalDataSource(database));

    final ProductRepository productRepository =
        LocalProductRepository(ProductLocalDataSource(database));

    // Помощник: локальные правила работают всегда; если при сборке задан
    // ключ или адрес сервера, отвечает языковая модель, а локальный
    // движок остаётся запасным на случай отсутствия сети.
    final AssistantEngine localEngine =
        LocalAssistantEngine(recommendationRepository);
    final AssistantEngine assistantEngine = aiConfig.isEnabled
        ? ClaudeAssistantEngine(config: aiConfig, fallback: localEngine)
        : localEngine;

    return AppDependencies._(
      userRepository: userRepository,
      productRepository: productRepository,
      orderRepository: LocalOrderRepository(OrderLocalDataSource(database)),
      cartRepository: LocalCartRepository(CartLocalDataSource(database)),
      recommendationRepository: recommendationRepository,
      favoritesRepository:
          LocalFavoritesRepository(FavoritesLocalDataSource(database)),
      feedbackRepository: LocalFeedbackRepository(database),
      fittingRepository: LocalFittingRepository(database),
      mediaStorage: mediaStorage ?? DeviceMediaStorage(),
      authService: AuthService(
        userRepository: userRepository,
        sessionStorage: sessionStorage ?? SharedPreferencesSessionStorage(),
      ),
      recommendationService: RecommendationService(
        LocalRecommendationEngine(recommendationRepository),
      ),
      kitService: KitService(recommendationRepository),
      assistantService: AssistantService(assistantEngine, productRepository),
    );
  }

  final UserRepository userRepository;
  final ProductRepository productRepository;
  final OrderRepository orderRepository;
  final CartRepository cartRepository;
  final RecommendationRepository recommendationRepository;
  final FavoritesRepository favoritesRepository;
  final FeedbackRepository feedbackRepository;
  final FittingRepository fittingRepository;
  final MediaStorage mediaStorage;
  final AuthService authService;
  final RecommendationService recommendationService;
  final KitService kitService;
  final AssistantService assistantService;
}
