import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../models/order.dart';
import '../../state/order_state.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/order_card.dart';

/// История заказов (фрейм Figma «история заказов»).
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Загрузка после первого кадра, чтобы не уведомлять слушателей во время build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<OrderState>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final OrderState state = context.watch<OrderState>();
    final List<Order> orders = state.orders;

    Widget body;
    if (state.isLoading && orders.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.error != null && orders.isEmpty) {
      body = EmptyState(
        icon: Icons.cloud_off,
        title: 'Ошибка загрузки',
        message: state.error,
        actionText: 'Повторить',
        onAction: state.load,
      );
    } else if (orders.isEmpty) {
      body = EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Заказов пока нет',
        message: 'Оформленные заказы появятся здесь',
        actionText: 'Перейти в каталог',
        onAction: () => Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.main,
          (route) => false,
          arguments: MainTab.catalog,
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: state.load,
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          itemCount: orders.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppSizes.s),
          itemBuilder: (context, index) => OrderCard(
            order: orders[index],
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.orderDetails,
              arguments: orders[index].id,
            ),
          ),
        ),
      );
    }

    return AppScaffold(
      title: 'История заказов',
      navTab: MainTab.profile,
      body: body,
    );
  }
}
