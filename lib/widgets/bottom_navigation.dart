import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/routes/main_tab.dart';
import '../core/theme/app_text_styles.dart';

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
                  isSelected: tab == currentTab,
                  badgeCount: tab == MainTab.basket ? basketCount : 0,
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
    required this.isSelected,
    required this.badgeCount,
    required this.onTap,
  });

  final MainTab tab;
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
                isSelected ? tab.activeIcon : tab.icon,
                color: color,
                size: AppSizes.iconM,
              ),
            ),
            const SizedBox(height: AppSizes.xxs),
            Text(tab.label, style: AppTextStyles.navLabel.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
