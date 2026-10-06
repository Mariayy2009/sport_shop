import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/main_tab.dart';
import '../../state/auth_state.dart';
import '../../state/cart_state.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bottom_navigation.dart';
import '../../widgets/guest_prompt.dart';
import '../cart/cart_screen.dart';
import '../catalog/catalog_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../recommendation/recommendation_intro_screen.dart';

/// Основная часть приложения: шапка + вкладки + нижняя навигация.
/// IndexedStack сохраняет состояние вкладок при переключении.
/// Гость видит каталог; AI, корзина и профиль — только после входа.
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
    setState(() => _currentTab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoggedIn = context.watch<AuthState>().isLoggedIn;
    final int basketCount = context.watch<CartState>().totalQuantity;

    return Scaffold(
      appBar: AppHeader(onProfileTap: () => _selectTab(MainTab.profile)),
      body: IndexedStack(
        index: _currentTab.index,
        children: [
          for (final MainTab tab in MainTab.values) _buildTab(tab, isLoggedIn),
        ],
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentTab: _currentTab,
        basketCount: basketCount,
        onTabSelected: _selectTab,
      ),
    );
  }

  Widget _buildTab(MainTab tab, bool isLoggedIn) {
    return switch (tab) {
      MainTab.home => HomeScreen(
          onOpenCatalog: () => _selectTab(MainTab.catalog),
          onOpenAi: () => _selectTab(MainTab.ai),
        ),
      MainTab.catalog => const CatalogScreen(),
      MainTab.ai => isLoggedIn
          ? RecommendationIntroScreen(
              onDecline: () => _selectTab(MainTab.home),
            )
          : const GuestPrompt(
              title: 'AI-подбор экипировки',
              message: 'Войдите, чтобы получить персональный набор '
                  'экипировки под ваш вид спорта и уровень',
              icon: Icons.auto_awesome_outlined,
            ),
      MainTab.basket => isLoggedIn
          ? CartScreen(onGoShopping: () => _selectTab(MainTab.catalog))
          : const GuestPrompt(
              title: 'Корзина',
              message: 'Войдите, чтобы добавлять товары в корзину '
                  'и оформлять заказы',
              icon: Icons.shopping_basket_outlined,
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
