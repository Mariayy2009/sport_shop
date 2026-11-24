import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item_options.dart';
import '../../models/product.dart';
import '../../models/user_sizes.dart';
import '../../state/auth_state.dart';
import '../../state/cart_state.dart';
import '../../state/profile_state.dart';
import '../../widgets/size_picker_sheet.dart';
import '../errors/app_exception.dart';
import '../routes/app_routes.dart';
import '../routes/main_tab.dart';
import 'app_messages.dart';

/// Добавление в корзину с любого экрана по одним правилам:
/// гость → предложение войти; нет в наличии → предупреждение;
/// нужен размер → подставляем размер из профиля или спрашиваем.
class CartActions {
  CartActions._();

  static Future<bool> addToCart(
    BuildContext context,
    Product product, {
    String? size,
    String? variant,
    bool askSizeIfUnknown = true,
  }) async {
    final NavigatorState navigator = Navigator.of(context);

    if (!context.read<AuthState>().isLoggedIn) {
      final bool goToLogin = await AppMessages.showConfirmDialog(
        context,
        title: 'Нужен вход',
        message: 'Чтобы добавлять товары в корзину, войдите в аккаунт '
            'или зарегистрируйтесь',
        confirmText: 'Войти',
      );
      if (goToLogin) navigator.pushNamed(AppRoutes.login);
      return false;
    }

    if (!product.isAvailable) {
      AppMessages.showWarning(
        context,
        'Товар «${product.name}» закончился. Недоступен для заказа',
      );
      return false;
    }

    // Вариант не выбран (добавили из каталога) — первый, как на главном фото.
    final String? chosenVariant = variant ??
        (product.variants.isEmpty ? null : product.variants.first.name);
    String? chosenSize = size;
    if (product.requiresSize && chosenSize == null) {
      final UserSizes? sizes = context.read<ProfileState>().sizes;
      final String? suggested = product.pickSize(
        clothingSize: sizes?.clothingSize,
        shoeSize: sizes?.shoeSize,
      );
      if (suggested != null && !askSizeIfUnknown) {
        chosenSize = suggested;
      } else {
        chosenSize = await SizePickerSheet.show(
          context,
          product,
          initialSize: suggested,
        );
        if (chosenSize == null) return false;
      }
    }

    if (!context.mounted) return false;
    try {
      // Размер и выбранный вариант (цвет, модель) — одной строкой.
      await context.read<CartState>().add(
            product,
            size: ItemOptions(size: chosenSize, variant: chosenVariant).encode(),
          );
      if (!context.mounted) return true;
      AppMessages.show(
        context,
        'Товар добавлен в корзину',
        type: MessageType.success,
        actionLabel: 'Корзина',
        onAction: () => navigator.pushNamedAndRemoveUntil(
          AppRoutes.main,
          (route) => false,
          arguments: MainTab.basket,
        ),
      );
      return true;
    } on AppException catch (error) {
      if (context.mounted) AppMessages.showWarning(context, error.message);
      return false;
    }
  }
}
