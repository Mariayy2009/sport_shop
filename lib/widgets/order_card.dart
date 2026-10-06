import 'package:flutter/material.dart';

import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import 'app_card.dart';
import 'status_chip.dart';

/// Карточка заказа в истории: номер, дата, статус, товары, сумма.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const int visibleItems = 2;
    final List<OrderItem> items = order.items;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Заказ ${Formatters.orderNumber(order.id ?? 0)}',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: AppSizes.s),
              Text(Formatters.date(order.createdAt), style: AppTextStyles.caption),
              const Spacer(),
              StatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: AppSizes.s),
          for (final OrderItem item in items.take(visibleItems))
            Text(
              '${item.productName ?? 'Товар'} × ${item.quantity}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySecondary,
            ),
          if (items.length > visibleItems)
            Text(
              'и ещё ${Formatters.itemsCount(items.length - visibleItems)}',
              style: AppTextStyles.caption,
            ),
          const SizedBox(height: AppSizes.s),
          Row(
            children: [
              Text(
                Formatters.itemsCount(order.itemsCount),
                style: AppTextStyles.caption,
              ),
              const Spacer(),
              Text(
                Formatters.price(order.totalPrice),
                style: AppTextStyles.price,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
