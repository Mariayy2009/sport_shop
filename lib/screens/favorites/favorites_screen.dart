import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../models/product.dart';
import '../../state/auth_state.dart';
import '../../state/favorites_state.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/guest_prompt.dart';
import '../../widgets/product_grid_card.dart';

/// Избранное: товары, отмеченные сердечком.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isLoggedIn = context.watch<AuthState>().isLoggedIn;
    final List<Product> items = context.watch<FavoritesState>().items;

    return AppScaffold(
      title: 'Избранное',
      navTab: MainTab.profile,
      body: !isLoggedIn
          ? const GuestPrompt(
              title: 'Избранное',
              message: 'Войдите, чтобы сохранять понравившиеся товары',
              icon: Icons.favorite_border,
            )
          : items.isEmpty
              ? EmptyState(
                  icon: Icons.favorite_border,
                  title: 'В избранном пока пусто',
                  message: 'Нажмите на сердечко в карточке товара, '
                      'чтобы вернуться к нему позже',
                  actionText: 'Перейти в каталог',
                  onAction: () => Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.main,
                    (route) => false,
                    arguments: MainTab.catalog,
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(AppSizes.screenPadding),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSizes.m,
                    crossAxisSpacing: AppSizes.m,
                    childAspectRatio: ProductGridCard.aspectRatio,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      ProductGridCard(product: items[index]),
                ),
    );
  }
}
