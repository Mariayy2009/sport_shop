import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'stage_placeholder_screen.dart';

/// Централизованная навигация.
/// Все переходы проходят через onGenerateRoute: здесь же
/// позже будет проверка роли (гость не попадёт в корзину и профиль).
class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final String routeName = settings.name ?? AppRoutes.main;

    switch (routeName) {
      // На этапах 6–10 сюда будут добавляться реальные экраны:
      // case AppRoutes.login:
      //   return _buildPage(settings, const LoginScreen());
      default:
        return _buildPage(
          settings,
          StagePlaceholderScreen(routeName: routeName),
        );
    }
  }

  static MaterialPageRoute<dynamic> _buildPage(
    RouteSettings settings,
    Widget screen,
  ) {
    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (_) => screen,
    );
  }
}
