import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../state/auth_state.dart';
import '../../state/cart_state.dart';
import '../../state/compare_state.dart';
import '../../state/favorites_state.dart';
import '../errors/app_exception.dart';
import '../routes/app_routes.dart';
import '../routes/main_tab.dart';
import 'app_messages.dart';
import 'formatters.dart';

/// Действия с товаром, одинаковые на всех экранах:
/// избранное, сравнение, добавление набора товаров в корзину.
class ProductActions {
  ProductActions._();

  static Future<void> toggleFavorite(BuildContext context, Product product) async {
    final NavigatorState navigator = Navigator.of(context);
    if (!context.read<AuthState>().isLoggedIn) {
      final bool goToLogin = await AppMessages.showConfirmDialog(
        context,
        title: 'Нужен вход',
        message: 'Чтобы сохранять товары в избранное, войдите в аккаунт '
            'или зарегистрируйтесь',
        confirmText: 'Войти',
      );
      if (goToLogin) navigator.pushNamed(AppRoutes.login);
      return;
    }
    try {
      final bool added = await context.read<FavoritesState>().toggle(product);
      if (!context.mounted) return;
      AppMessages.show(
        context,
        added ? 'Добавлено в избранное' : 'Убрано из избранного',
        type: added ? MessageType.success : MessageType.info,
        actionLabel: added ? 'Открыть' : null,
        onAction: added ? () => navigator.pushNamed(AppRoutes.favorites) : null,
      );
    } on AppException catch (error) {
      if (context.mounted) AppMessages.showWarning(context, error.message);
    }
  }

  static void toggleCompare(BuildContext context, Product product) {
    final NavigatorState navigator = Navigator.of(context);
    final CompareState compare = context.read<CompareState>();
    try {
      final bool added = compare.toggle(product);
      AppMessages.show(
        context,
        added
            ? 'В сравнении: ${Formatters.itemsCount(compare.count)}'
            : 'Убрано из сравнения',
        type: added ? MessageType.success : MessageType.info,
        actionLabel: added && compare.count > 1 ? 'Сравнить' : null,
        onAction: added && compare.count > 1
            ? () => navigator.pushNamed(AppRoutes.compare)
            : null,
      );
    } on AppException catch (error) {
      AppMessages.showWarning(context, error.message);
    }
  }

  /// Добавляет несколько товаров с уже подобранными размерами
  /// (комплект, подборка помощника). Товары, которые уже в корзине,
  /// пропускаются. Возвращает количество добавленных.
  static Future<int> addAllToCart(
    BuildContext context,
    List<({Product product, String? size})> items,
  ) async {
    final NavigatorState navigator = Navigator.of(context);
    if (!context.read<AuthState>().isLoggedIn) {
      navigator.pushNamed(AppRoutes.login);
      return 0;
    }
    final CartState cart = context.read<CartState>();
    int added = 0;
    final List<String> skipped = [];
    for (final ({Product product, String? size}) item in items) {
      if (cart.containsProduct(item.product.id)) continue;
      final String? size = item.size ?? item.product.availableSizes.firstOrNull;
      try {
        await cart.add(item.product, size: size);
        added++;
      } on AppException {
        skipped.add(item.product.name);
      }
    }
    if (!context.mounted) return added;
    if (added == 0 && skipped.isEmpty) {
      AppMessages.showInfo(context, 'Эти товары уже в корзине');
      return 0;
    }
    AppMessages.show(
      context,
      skipped.isEmpty
          ? 'Добавлено в корзину: ${Formatters.itemsCount(added)}'
          : 'Добавлено: $added. Недоступны: ${skipped.join(', ')}',
      type: skipped.isEmpty ? MessageType.success : MessageType.warning,
      actionLabel: 'Корзина',
      onAction: () => navigator.pushNamedAndRemoveUntil(
        AppRoutes.main,
        (route) => false,
        arguments: MainTab.basket,
      ),
    );
    return added;
  }
}
