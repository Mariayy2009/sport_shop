import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/main_tab.dart';
import '../../models/enums.dart';
import '../../state/auth_state.dart';
import '../../state/notification_state.dart';
import '../../state/cart_state.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bottom_navigation.dart';
import '../../widgets/guest_prompt.dart';
import '../admin/admin_screen.dart';
import '../admin/admin_sellers_screen.dart';
import '../assistant/assistant_screen.dart';
import '../cart/cart_screen.dart';
import '../catalog/catalog_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../seller/seller_scan_screen.dart';
import '../seller/seller_screen.dart';

/// Основная часть приложения: шапка + вкладки + нижняя навигация.
/// IndexedStack сохраняет состояние вкладок при переключении.
/// Гость видит каталог и помощника; корзина и профиль — после входа.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialTab = MainTab.home});

  final MainTab initialTab;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late MainTab _currentTab = widget.initialTab;

  void _selectTab(MainTab tab) {
    if (tab == _currentTab) return;
    // Корзина и уведомления перечитываются при открытии: товар могли
    // снять с продажи, продавец мог ответить.
    if (tab == MainTab.basket) unawaited(context.read<CartState>().refresh());
    if (tab == MainTab.profile) {
      unawaited(context.read<NotificationState>().refresh());
    }
    setState(() => _currentTab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoggedIn = context.watch<AuthState>().isLoggedIn;
    final UserRole role =
        context.watch<AuthState>().currentUser?.role ?? UserRole.guest;
    final int basketCount = context.watch<CartState>().totalQuantity;

    return Scaffold(
      appBar: AppHeader(onProfileTap: () => _selectTab(MainTab.profile)),
      body: IndexedStack(
        index: _currentTab.index,
        children: [
          for (final MainTab tab in MainTab.values)
            _buildTab(tab, isLoggedIn, role),
        ],
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentTab: _currentTab,
        basketCount: basketCount,
        onTabSelected: _selectTab,
      ),
    );
  }

  Widget _buildTab(MainTab tab, bool isLoggedIn, UserRole role) {
    // У продавца и администратора на месте «Помощника» и «Корзины» —
    // свои разделы.
    if (role == UserRole.seller) {
      if (tab == MainTab.ai) return const SellerScanScreen(embedded: true);
      if (tab == MainTab.basket) return const SellerScreen(embedded: true);
    }
    if (role == UserRole.admin) {
      if (tab == MainTab.ai) return const AdminScreen(embedded: true);
      if (tab == MainTab.basket) return const AdminSellersScreen();
    }
    return switch (tab) {
      MainTab.home => HomeScreen(
          onOpenCatalog: () => _selectTab(MainTab.catalog),
          onOpenAi: () => _selectTab(MainTab.ai),
        ),
      MainTab.catalog => const CatalogScreen(),
      // Помощник доступен и гостю: спросить совет можно без аккаунта.
      MainTab.ai => const AssistantScreen(),
      MainTab.basket => isLoggedIn
          ? CartScreen(onGoShopping: () => _selectTab(MainTab.catalog))
          : const GuestPrompt(
              title: 'Корзина',
              message: 'Войдите, чтобы добавлять товары в корзину '
                  'и оформлять заказы',
              icon: Icons.shopping_bag_outlined,
            ),
      MainTab.profile => isLoggedIn
          ? ProfileScreen(onOpenAi: () => _selectTab(MainTab.ai))
          : const GuestPrompt(
              title: 'Профиль',
              message: 'Войдите или зарегистрируйтесь, чтобы хранить '
                  'размеры, получать рекомендации и видеть историю заказов',
              icon: Icons.person_outline,
            ),
    };
  }
}
