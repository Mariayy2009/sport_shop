import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/routes/app_routes.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/app_messages.dart';
import '../core/utils/formatters.dart';
import '../data/repositories/order_repository.dart';
import '../models/enums.dart';
import '../models/order.dart';
import '../models/item_options.dart';
import '../models/order_item.dart';
import 'app_card.dart';
import 'status_chip.dart';
import 'text_input_sheet.dart';

/// Заказ в панели администратора или в кабинете продавца: статус
/// (новый / в пути / доставлен) и «где товар» — это видит покупатель
/// в своём заказе.
class OrderManageCard extends StatelessWidget {
  const OrderManageCard({
    super.key,
    required this.order,
    required this.onChanged,
    this.onlyProductIds,
  });

  final Order order;

  /// Вызывается после изменения — список перечитывается.
  final VoidCallback onChanged;

  /// Продавцу показываем только его товары в заказе.
  final Set<int>? onlyProductIds;

  Future<void> _setStatus(BuildContext context, OrderStatus status) async {
    if (status == order.status) return;
    await context.read<OrderRepository>().updateStatus(order.id!, status);
    if (!context.mounted) return;
    AppMessages.showSuccess(
      context,
      'Заказ ${Formatters.orderNumber(order.id!)}: «${status.label}»',
    );
    onChanged();
  }

  Future<void> _editTracking(BuildContext context) async {
    final OrderRepository repository = context.read<OrderRepository>();
    final String? text = await TextInputSheet.show(
      context,
      title: 'Где товар',
      subtitle: 'Покупатель увидит это в своём заказе',
      hint: 'Например: отправлен из Алматы, привезём 27 ноября',
      buttonText: 'Сохранить',
      maxLength: 200,
      initialText: order.trackingNote ?? '',
    );
    if (text == null) return;
    await repository.updateTracking(order.id!, text.isEmpty ? null : text);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> items = [
      for (final OrderItem item in order.items)
        if (onlyProductIds == null || onlyProductIds!.contains(item.productId))
          '${item.productName ?? 'Товар'} × ${item.quantity}'
              '${item.size == null ? '' : ' (${ItemOptions.decode(item.size).label})'}',
    ];
    return AppCard(
      onTap: () => Navigator.of(context)
          .pushNamed(AppRoutes.orderDetails, arguments: order.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Заказ ${Formatters.orderNumber(order.id!)}',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              StatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: AppSizes.xxs),
          Text(
            '${Formatters.date(order.createdAt)} · '
            '${order.customerName ?? 'Покупатель'} · '
            '${order.deliveryMethod.label}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSizes.xs),
          for (final String item in items)
            Text(item, style: AppTextStyles.bodySecondary),
          const SizedBox(height: AppSizes.s),
          SegmentedButton<OrderStatus>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              backgroundColor: AppColors.surface,
              selectedBackgroundColor: AppColors.black,
              selectedForegroundColor: AppColors.white,
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              textStyle:
                  AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
            ),
            segments: [
              for (final OrderStatus status in OrderStatus.values)
                ButtonSegment(value: status, label: Text(status.label)),
            ],
            selected: {order.status},
            onSelectionChanged: (value) => _setStatus(context, value.first),
          ),
          const SizedBox(height: AppSizes.xs),
          InkWell(
            onTap: () => _editTracking(context),
            borderRadius: BorderRadius.circular(AppSizes.radiusS),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 18),
                  const SizedBox(width: AppSizes.xs),
                  Expanded(
                    child: Text(
                      order.trackingNote ?? 'Где товар? Нажмите, чтобы написать',
                      style: order.trackingNote == null
                          ? AppTextStyles.caption
                          : AppTextStyles.bodySecondary,
                    ),
                  ),
                  const Icon(Icons.edit_outlined, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
