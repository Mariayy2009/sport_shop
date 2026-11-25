import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../models/exhibit.dart';
import '../../models/product.dart';
import '../../screens/admin/admin_exhibit_screen.dart';
import '../../screens/admin/admin_product_screen.dart';
import '../../screens/admin/admin_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/registration_screen.dart';
import '../../screens/cart/checkout_screen.dart';
import '../../screens/cart/order_success_screen.dart';
import '../../screens/catalog/filter_screen.dart';
import '../../screens/catalog/product_screen.dart';
import '../../screens/common/not_found_screen.dart';
import '../../screens/compare/compare_screen.dart';
import '../../screens/exhibits/exhibit_screen.dart';
import '../../screens/exhibits/hall_of_fame_screen.dart';
import '../../screens/games/ball_game_screen.dart';
import '../../screens/profile/preferences_screen.dart';
import '../../screens/seller/seller_screen.dart';
import '../../screens/recommendation/preference_results_screen.dart';
import '../../services/games/ball_game.dart';
import '../../screens/favorites/favorites_screen.dart';
import '../../screens/kits/kits_screen.dart';
import '../../screens/try_on/live_try_on_screen.dart';
import '../../screens/try_on/photo_try_on_screen.dart';
import '../../screens/try_on/try_on_screen.dart';
import '../../screens/orders/order_details_screen.dart';
import '../../screens/orders/order_history_screen.dart';
import '../../screens/profile/edit_profile_screen.dart';
import '../../screens/recommendation/recommendation_quiz_screen.dart';
import '../../screens/recommendation/recommendation_result_screen.dart';
import '../../screens/profile/notifications_screen.dart';
import '../../screens/shell/main_shell.dart';
import 'app_routes.dart';
import 'main_tab.dart';

/// Централизованная навигация: все переходы проходят через onGenerateRoute.
/// Здесь же проверяются аргументы перехода (id товара, заказ).
class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final Object? args = settings.arguments;

    final Widget screen = switch (settings.name) {
      AppRoutes.main =>
        MainShell(initialTab: args is MainTab ? args : MainTab.home),
      AppRoutes.login => const LoginScreen(),
      AppRoutes.registration => const RegistrationScreen(),
      AppRoutes.filter => const FilterScreen(),
      AppRoutes.product when args is int => ProductScreen(productId: args),
      AppRoutes.editProfile => const EditProfileScreen(),
      AppRoutes.checkout => const CheckoutScreen(),
      AppRoutes.orderSuccess when args is Order =>
        OrderSuccessScreen(order: args),
      AppRoutes.orderHistory => const OrderHistoryScreen(),
      AppRoutes.orderDetails when args is int =>
        OrderDetailsScreen(orderId: args),
      AppRoutes.recommendationQuiz => const RecommendationQuizScreen(),
      AppRoutes.recommendationResult => const RecommendationResultScreen(),
      AppRoutes.kits => KitsScreen(initialSportId: args is int ? args : null),
      AppRoutes.compare => const CompareScreen(),
      AppRoutes.favorites => const FavoritesScreen(),
      AppRoutes.tryOn => TryOnScreen(productId: args is int ? args : null),
      AppRoutes.photoTryOn =>
        PhotoTryOnScreen(productId: args is int ? args : null),
      AppRoutes.liveTryOn =>
        LiveTryOnScreen(productId: args is int ? args : null),
      AppRoutes.hallOfFame => const HallOfFameScreen(),
      AppRoutes.preferences => const PreferencesScreen(),
      AppRoutes.seller => const SellerScreen(),
      AppRoutes.notifications => const NotificationsScreen(),
      AppRoutes.preferenceResults => const PreferenceResultsScreen(),
      AppRoutes.ballGame => BallGameScreen(
          initialMode: args is BallGameMode ? args : BallGameMode.football,
        ),
      AppRoutes.exhibit when args is int => ExhibitScreen(exhibitId: args),
      AppRoutes.adminExhibit =>
        AdminExhibitScreen(exhibit: args is Exhibit ? args : null),
      AppRoutes.admin => const AdminScreen(),
      AppRoutes.adminProduct =>
        AdminProductScreen(product: args is Product ? args : null),
      _ => const NotFoundScreen(),
    };

    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (_) => screen,
    );
  }
}
