import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/routes/main_tab.dart';
import '../core/theme/app_text_styles.dart';
import '../models/enums.dart';
import '../state/auth_state.dart';
import '../state/seller_badge_state.dart';

/// Нижняя навигация из Figma: Home / Catalog / AI / Basket / Profile.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
    this.basketCount = 0,
  });

  final MainTab currentTab;
  final ValueChanged<MainTab> onTabSelected;

  /// Количество товаров в корзине — бейдж на иконке Basket.
  final int basketCount;

  @override
  Widget build(BuildContext context) {
    final UserRole role =
        context.watch<AuthState>().currentUser?.role ?? UserRole.guest;
    // У продавца на «Кабинете» — новые предупреждения и вопросы.
    final int sellerCount = role == UserRole.seller
        ? context.watch<SellerBadgeState>().total
        : 0;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSizes.bottomNavHeight,
          child: Row(
            children: [
              for (final MainTab tab in MainTab.values)
                _NavItem(
                  tab: tab,
                  role: role,
                  isSelected: tab == currentTab,
                  // Бейдж корзины — только у покупателя.
                  badgeCount: tab != MainTab.basket
                      ? 0
                      : role == UserRole.seller
                          ? sellerCount
                          : role == UserRole.admin
                              ? 0
                              : basketCount,
                  onTap: () => onTabSelected(tab),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.role,
    required this.isSelected,
    required this.badgeCount,
    required this.onTap,
  });

  final MainTab tab;
  final UserRole role;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = isSelected ? AppColors.navActive : AppColors.navInactive;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badgeCount > 0,
              backgroundColor: AppColors.logoRed,
              label: Text('$badgeCount'),
              child: Icon(
                tab.iconFor(role, selected: isSelected),
                color: color,
                size: AppSizes.iconM,
              ),
            ),
            const SizedBox(height: AppSizes.xxs),
            Text(tab.labelFor(role), style: AppTextStyles.navLabel.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
