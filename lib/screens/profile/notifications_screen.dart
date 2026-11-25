import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_notification.dart';
import '../../state/notification_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';

/// Уведомления: ответы продавцов, статус заказов, промокоды,
/// у продавца — «товар заканчивается».
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final Future<void> _opening = context.read<NotificationState>().open();

  void _openTarget(AppNotification item) {
    if (item.orderId != null) {
      Navigator.of(context).pushNamed(AppRoutes.orderDetails, arguments: item.orderId);
    } else if (item.productId != null) {
      Navigator.of(context).pushNamed(AppRoutes.product, arguments: item.productId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<AppNotification> items = context.watch<NotificationState>().items;
    return AppScaffold(
      title: 'Уведомления',
      navTab: MainTab.profile,
      body: FutureBuilder<void>(
        future: _opening,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'Уведомлений пока нет',
              message: 'Здесь появятся ответы продавцов и новости о заказах',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSizes.s),
            itemBuilder: (context, index) {
              final AppNotification item = items[index];
              return AppCard(
                onTap: item.orderId == null && item.productId == null
                    ? null
                    : () => _openTarget(item),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      item.isRead ? Icons.notifications_none : Icons.notifications_active,
                      color: item.isRead ? AppColors.textSecondary : AppColors.logoRed,
                    ),
                    const SizedBox(width: AppSizes.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (item.body != null)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSizes.xxs),
                              child: Text(item.body!, style: AppTextStyles.body),
                            ),
                          const SizedBox(height: AppSizes.xxs),
                          Text(Formatters.date(item.createdAt), style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
