import 'dart:async';

import '../core/di/app_dependencies.dart';
import 'assistant_state.dart';
import 'auth_state.dart';
import 'cart_state.dart';
import 'compare_state.dart';
import 'favorites_state.dart';
import 'try_on_controller.dart';
import 'order_state.dart';
import 'product_state.dart';
import 'profile_state.dart';
import 'recommendation_state.dart';

/// Все состояния приложения и их связь между собой:
/// при входе / выходе пользователя корзина, профиль и заказы
/// автоматически переключаются на нового пользователя.
class AppStates {
  AppStates._({
    required this.auth,
    required this.products,
    required this.cart,
    required this.profile,
    required this.orders,
    required this.recommendation,
    required this.favorites,
    required this.compare,
    required this.assistant,
    required this.tryOn,
  });

  factory AppStates.create(AppDependencies deps) {
    final AppStates states = AppStates._(
      auth: AuthState(deps.authService),
      products: ProductState(deps.productRepository),
      cart: CartState(deps.cartRepository),
      profile: ProfileState(deps.userRepository, deps.mediaStorage),
      orders: OrderState(deps.orderRepository),
      recommendation: RecommendationState(deps.recommendationService),
      favorites: FavoritesState(deps.favoritesRepository),
      compare: CompareState(),
      assistant: AssistantState(deps.assistantService),
      tryOn: TryOnController(
        deps.tryOnRepository,
        deps.photoTryOnService,
        deps.mediaStorage,
      ),
    );
    states.auth.addListener(states._onAuthChanged);
    return states;
  }

  final AuthState auth;
  final ProductState products;
  final CartState cart;
  final ProfileState profile;
  final OrderState orders;
  final RecommendationState recommendation;
  final FavoritesState favorites;
  final CompareState compare;
  final AssistantState assistant;
  final TryOnController tryOn;

  /// Загрузка при старте: сессия «Запомнить меня» и каталог.
  Future<void> init() async {
    await auth.restoreSession();
    await products.init();
  }

  void _onAuthChanged() {
    final int? userId = auth.currentUser?.id;
    unawaited(cart.setUser(userId));
    unawaited(profile.setUser(userId));
    unawaited(orders.setUser(userId));
    unawaited(favorites.setUser(userId));
    assistant.setUser(userId);
    unawaited(tryOn.setUser(userId));
  }
}
