import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_sizes.dart';
import '../core/routes/app_routes.dart';
import '../core/routes/main_tab.dart';
import '../state/cart_state.dart';
import 'app_header.dart';
import 'bottom_navigation.dart';
import 'screen_title_bar.dart';

/// Каркас внутренних экранов (товар, фильтры, заказ...):
/// шапка + строка заголовка + содержимое + кнопка действия + нижняя
/// навигация — как на макетах Figma.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleTrailing,
    this.showBack = true,
    this.navTab,
    this.bottomAction,
  });

  final Widget body;
  final String? title;
  final Widget? titleTrailing;
  final bool showBack;

  /// Если задана — внизу показывается навигация с этой активной вкладкой.
  final MainTab? navTab;

  /// Кнопка над навигацией: «Положить в корзину», «Подтвердить заказ».
  final Widget? bottomAction;

  @override
  Widget build(BuildContext context) {
    final MainTab? tab = navTab;
    Widget? bottom;
    if (bottomAction != null || tab != null) {
      final Widget action = Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.l,
          AppSizes.s,
          AppSizes.l,
          AppSizes.s,
        ),
        child: bottomAction,
      );
      bottom = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (bottomAction != null)
            tab == null ? SafeArea(top: false, child: action) : action,
          if (tab != null)
            AppBottomNavigation(
              currentTab: tab,
              basketCount: context.watch<CartState>().totalQuantity,
              onTabSelected: (selected) => Navigator.of(context)
                  .pushNamedAndRemoveUntil(
                      AppRoutes.main, (route) => false,
                      arguments: selected),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: const AppHeader(),
      body: Column(
        children: [
          if (title != null)
            ScreenTitleBar(
              title: title!,
              showBack: showBack,
              trailing: titleTrailing,
            ),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: bottom,
    );
  }
}
