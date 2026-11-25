import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_strings.dart';
import 'core/di/app_dependencies.dart';
import 'core/routes/app_router.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'data/database/app_database.dart';
import 'data/database/database_helper.dart';
import 'data/repositories/exhibit_repository.dart';
import 'data/repositories/feedback_repository.dart';
import 'data/repositories/game_repository.dart';
import 'data/repositories/moderation_repository.dart';
import 'data/repositories/order_repository.dart';
import 'data/repositories/preferences_repository.dart';
import 'data/repositories/product_repository.dart';
import 'data/repositories/try_on_scan_repository.dart';
import 'data/repositories/user_repository.dart';
import 'services/assistant/configurable_assistant_engine.dart';
import 'services/kit_service.dart';
import 'services/media_storage.dart';
import 'services/recommendation_service.dart';
import 'state/app_states.dart';
import 'state/assistant_state.dart';
import 'state/auth_state.dart';
import 'state/cart_state.dart';
import 'state/data_source_state.dart';
import 'state/compare_state.dart';
import 'state/favorites_state.dart';
import 'state/try_on_controller.dart';
import 'state/order_state.dart';
import 'state/product_state.dart';
import 'state/profile_state.dart';
import 'state/recommendation_state.dart';
import 'state/notification_state.dart';
import 'state/seller_badge_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Макеты Figma только портретные
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // SQLite: выбор реализации под платформу (Android / Windows)
  DatabaseHelper.initPlatform();
  // При первом запуске создаются таблицы и демо-данные
  await AppDatabase.instance.database;

  final AppDependencies dependencies =
      AppDependencies.local(AppDatabase.instance);
  final AppStates states = AppStates.create(dependencies);
  // Вход из «Запомнить меня» + загрузка каталога
  await states.init();

  runApp(SportShopApp(dependencies: dependencies, states: states));
}

class SportShopApp extends StatelessWidget {
  const SportShopApp({
    super.key,
    required this.dependencies,
    required this.states,
  });

  final AppDependencies dependencies;
  final AppStates states;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Репозитории и сервисы — для экранов, которым нужны разовые запросы
        Provider<UserRepository>.value(value: dependencies.userRepository),
        Provider<ProductRepository>.value(value: dependencies.productRepository),
        Provider<OrderRepository>.value(value: dependencies.orderRepository),
        Provider<RecommendationService>.value(
          value: dependencies.recommendationService,
        ),
        Provider<KitService>.value(value: dependencies.kitService),
        Provider<ConfigurableAssistantEngine>.value(
          value: dependencies.assistantEngine,
        ),
        Provider<MediaStorage>.value(value: dependencies.mediaStorage),
        Provider<TryOnScanRepository>.value(
          value: dependencies.tryOnScanRepository,
        ),
        Provider<GameRepository>.value(value: dependencies.gameRepository),
        Provider<ModerationRepository>.value(
          value: dependencies.moderationRepository,
        ),
        Provider<PreferencesRepository>.value(
          value: dependencies.preferencesRepository,
        ),
        Provider<ExhibitRepository>.value(
          value: dependencies.exhibitRepository,
        ),
        Provider<FeedbackRepository>.value(
          value: dependencies.feedbackRepository,
        ),
        // Состояния экранов
        ChangeNotifierProvider<AuthState>.value(value: states.auth),
        ChangeNotifierProvider<ProductState>.value(value: states.products),
        ChangeNotifierProvider<CartState>.value(value: states.cart),
        ChangeNotifierProvider<ProfileState>.value(value: states.profile),
        ChangeNotifierProvider<OrderState>.value(value: states.orders),
        ChangeNotifierProvider<RecommendationState>.value(
          value: states.recommendation,
        ),
        ChangeNotifierProvider<FavoritesState>.value(value: states.favorites),
        ChangeNotifierProvider<CompareState>.value(value: states.compare),
        ChangeNotifierProvider<AssistantState>.value(value: states.assistant),
        ChangeNotifierProvider<TryOnController>.value(value: states.tryOn),
        ChangeNotifierProvider<DataSourceState>.value(value: states.dataSource),
        ChangeNotifierProvider<NotificationState>.value(
          value: states.notifications,
        ),
        ChangeNotifierProvider<SellerBadgeState>.value(
          value: states.sellerBadges,
        ),
      ],
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        initialRoute: AppRoutes.main,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
