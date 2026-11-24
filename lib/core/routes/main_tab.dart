import 'package:flutter/material.dart';

import '../../models/enums.dart';
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

  /// У продавца и администратора вместо «Помощника» и «Корзины» — свои
  /// разделы: покупательские функции им не нужны и только путают роль.
  String labelFor(UserRole role) => switch ((this, role)) {
        (ai, UserRole.seller) => 'Сканер',
        (basket, UserRole.seller) => 'Кабинет',
        (ai, UserRole.admin) => 'Модерация',
        (basket, UserRole.admin) => 'Продавцы',
        _ => label,
      };

  IconData iconFor(UserRole role, {required bool selected}) =>
      switch ((this, role)) {
        (ai, UserRole.seller) =>
          selected ? Icons.view_in_ar : Icons.view_in_ar_outlined,
        (basket, UserRole.seller) =>
          selected ? Icons.storefront : Icons.storefront_outlined,
        (ai, UserRole.admin) =>
          selected ? Icons.gpp_maybe : Icons.gpp_maybe_outlined,
        (basket, UserRole.admin) => selected ? Icons.groups : Icons.groups_outlined,
        _ => selected ? activeIcon : icon,
      };
}
