import '../../data/database/app_database.dart';
import '../../data/datasources/local/cart_local_datasource.dart';
import '../../data/datasources/local/order_local_datasource.dart';
import '../../data/datasources/local/product_local_datasource.dart';
import '../../data/datasources/local/recommendation_local_datasource.dart';
import '../../data/datasources/local/session_local_datasource.dart';
import '../../data/datasources/local/user_local_datasource.dart';
import '../../data/repositories/cart_repository.dart';
import '../../data/repositories/local_cart_repository.dart';
import '../../data/repositories/local_order_repository.dart';
import '../../data/repositories/local_product_repository.dart';
import '../../data/repositories/local_recommendation_repository.dart';
import '../../data/repositories/local_user_repository.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/recommendation_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../services/auth_service.dart';
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
    required this.authService,
    required this.recommendationService,
  });

  factory AppDependencies.local(
    AppDatabase database, {
    SessionStorage? sessionStorage,
  }) {
    final UserRepository userRepository =
        LocalUserRepository(UserLocalDataSource(database));
    final RecommendationRepository recommendationRepository =
        LocalRecommendationRepository(RecommendationLocalDataSource(database));

    return AppDependencies._(
      userRepository: userRepository,
      productRepository:
          LocalProductRepository(ProductLocalDataSource(database)),
      orderRepository: LocalOrderRepository(OrderLocalDataSource(database)),
      cartRepository: LocalCartRepository(CartLocalDataSource(database)),
      recommendationRepository: recommendationRepository,
      authService: AuthService(
        userRepository: userRepository,
        sessionStorage: sessionStorage ?? SharedPreferencesSessionStorage(),
      ),
      recommendationService: RecommendationService(
        LocalRecommendationEngine(recommendationRepository),
      ),
    );
  }

  final UserRepository userRepository;
  final ProductRepository productRepository;
  final OrderRepository orderRepository;
  final CartRepository cartRepository;
  final RecommendationRepository recommendationRepository;
  final AuthService authService;
  final RecommendationService recommendationService;
}
