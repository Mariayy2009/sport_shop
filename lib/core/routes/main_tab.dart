import 'package:flutter/material.dart';

import '../constants/app_strings.dart';

/// Вкладки нижней навигации.
enum MainTab {
  home(AppStrings.navHome, Icons.home_outlined, Icons.home),
  catalog(AppStrings.navCatalog, Icons.grid_view_outlined, Icons.grid_view),
  ai(AppStrings.navAi, Icons.auto_awesome_outlined, Icons.auto_awesome),
  basket(AppStrings.navBasket, Icons.shopping_bag_outlined,
      Icons.shopping_bag),
  profile(AppStrings.navProfile, Icons.person_outline, Icons.person);

  const MainTab(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
