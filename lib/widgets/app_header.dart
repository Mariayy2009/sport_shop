import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/routes/app_routes.dart';
import '../core/routes/main_tab.dart';
import '../state/favorites_state.dart';
import 'app_logo.dart';

/// Белая шапка: логотип слева, избранное и профиль справа.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    this.showActions = true,
    this.showBackButton = false,
    this.onProfileTap,
  });

  final bool showActions;
  final bool showBackButton;
  final VoidCallback? onProfileTap;

  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.headerHeight);

  void _openProfile(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.main,
      (route) => false,
      arguments: MainTab.profile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final int favoritesCount = context.watch<FavoritesState>().count;
    return Material(
      color: AppColors.surface,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: AppSizes.headerHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.s),
              child: Row(
                children: [
                  if (showBackButton)
                    IconButton(
                      tooltip: 'Назад',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back),
                    )
                  else
                    const SizedBox(width: AppSizes.s),
                  const AppLogo(),
                  const Spacer(),
                  if (showActions) ...[
                    IconButton(
                      tooltip: 'Избранное',
                      onPressed: () => Navigator.of(context)
                          .pushNamed(AppRoutes.favorites),
                      icon: Badge(
                        isLabelVisible: favoritesCount > 0,
                        backgroundColor: AppColors.favorite,
                        label: Text('$favoritesCount'),
                        child: const Icon(Icons.favorite_border),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Профиль',
                      onPressed: onProfileTap ?? () => _openProfile(context),
                      icon: const Icon(Icons.account_circle_outlined),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
