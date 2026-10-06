import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';

/// Экран для неизвестного маршрута или неверных параметров перехода.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Страница не найдена',
      body: EmptyState(
        icon: Icons.explore_off_outlined,
        title: 'Такой страницы нет',
        message: 'Вернитесь на главную и попробуйте ещё раз',
        actionText: 'На главную',
        onAction: () => Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.main, (route) => false),
      ),
    );
  }
}
