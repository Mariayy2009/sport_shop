import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/product_repository.dart';
import '../../models/enums.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/product.dart';
import '../../state/cart_state.dart';
import '../../state/order_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_image.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/summary_row.dart';

/// Подробности заказа. Экрана нет в Figma — добавлен по сценарию 5.
class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late final Future<Order?> _future;
  bool _isRepeating = false;

  @override
  void initState() {
    super.initState();
    _future = context.read<OrderState>().getOrder(widget.orderId);
  }

  /// «Повторить заказ»: кладёт те же товары в корзину.
  Future<void> _repeat(Order order) async {
    setState(() => _isRepeating = true);
    final NavigatorState navigator = Navigator.of(context);
    final ProductRepository products = context.read<ProductRepository>();
    final CartState cart = context.read<CartState>();
    int added = 0;
    final List<String> problems = [];

    for (final OrderItem item in order.items) {
      final Product? product = await products.getProductById(item.productId);
      if (product == null) {
        problems.add(item.productName ?? 'товар');
        continue;
      }
      try {
        await cart.add(
          product,
          size: item.size ?? product.availableSizes.firstOrNull,
          quantity: item.quantity,
        );
        added++;
      } on AppException {
        problems.add(product.name);
      }
    }

    if (!mounted) return;
    setState(() => _isRepeating = false);
    if (added > 0) {
      AppMessages.show(
        context,
        problems.isEmpty
            ? 'Товары добавлены в корзину'
            : 'Добавлено: $added. Недоступны: ${problems.join(', ')}',
        type: problems.isEmpty ? MessageType.success : MessageType.warning,
        actionLabel: 'Корзина',
        onAction: () => navigator.pushNamedAndRemoveUntil(
          AppRoutes.main,
          (route) => false,
          arguments: MainTab.basket,
        ),
      );
    } else {
      AppMessages.showWarning(
        context,
        'Не удалось добавить товары: их нет в наличии',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Order?>(
      future: _future,
      builder: (context, snapshot) {
        final Order? order = snapshot.data;
        final String title = order == null
            ? 'Заказ'
            : 'Заказ ${Formatters.orderNumber(order.id ?? 0)}';

        if (snapshot.connectionState != ConnectionState.done) {
          return const AppScaffold(
            title: 'Заказ',
            navTab: MainTab.profile,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (order == null) {
          return const AppScaffold(
            title: 'Заказ',
            navTab: MainTab.profile,
            body: EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Заказ не найден',
            ),
          );
        }

        final double itemsTotal =
            order.items.fold(0, (sum, item) => sum + item.total);
        final double delivery = order.totalPrice - itemsTotal;

        return AppScaffold(
          title: title,
          navTab: MainTab.profile,
          bottomAction: CustomButton(
            text: 'Повторить заказ',
            variant: ButtonVariant.secondary,
            isLoading: _isRepeating,
            onPressed: () => _repeat(order),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'от ${Formatters.date(order.createdAt)}',
                            style: AppTextStyles.bodySecondary,
                          ),
                        ),
                        StatusChip(status: order.status),
                      ],
                    ),
                    const SizedBox(height: AppSizes.l),
                    _StatusProgress(status: order.status),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.m),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Товары', style: AppTextStyles.sectionTitle),
                    const SizedBox(height: AppSizes.s),
                    for (final OrderItem item in order.items)
                      _OrderItemRow(item: item),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.m),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Доставка', style: AppTextStyles.sectionTitle),
                    const SizedBox(height: AppSizes.s),
                    SummaryRow(label: 'Способ', value: order.deliveryMethod.label),
                    if (order.deliveryAddress != null)
                      Text(order.deliveryAddress!, style: AppTextStyles.body),
                    SummaryRow(label: 'Получатель', value: order.customerName ?? '—'),
                    SummaryRow(label: 'Телефон', value: order.phone ?? '—'),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.m),
              AppCard(
                child: Column(
                  children: [
                    SummaryRow(
                      label: 'Товары (${order.itemsCount})',
                      value: Formatters.price(itemsTotal),
                    ),
                    SummaryRow(
                      label: 'Доставка',
                      value: delivery <= 0
                          ? 'Бесплатно'
                          : Formatters.price(delivery),
                    ),
                    const Divider(),
                    SummaryRow(
                      label: 'Итого',
                      value: Formatters.price(order.totalPrice),
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context)
          .pushNamed(AppRoutes.product, arguments: item.productId),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
        child: Row(
          children: [
            ProductImage(
              imageUrl: item.productImageUrl,
              width: 48,
              height: 48,
              borderRadius: AppSizes.radiusS,
            ),
            const SizedBox(width: AppSizes.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.productName ?? 'Товар', style: AppTextStyles.body),
                  Text(
                    '${item.size == null ? '' : 'Размер ${item.size} · '}'
                    '${item.quantity} × ${Formatters.price(item.price)}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            Text(Formatters.price(item.total), style: AppTextStyles.price),
          ],
        ),
      ),
    );
  }
}

/// Шкала статуса: Новый → В пути → Доставлен.
class _StatusProgress extends StatelessWidget {
  const _StatusProgress({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    const List<OrderStatus> steps = OrderStatus.values;
    final int current = steps.indexOf(status);
    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= current ? AppColors.black : AppColors.surface,
                  border: Border.all(
                    color: i <= current ? AppColors.black : AppColors.border,
                    width: 2,
                  ),
                ),
                child: i <= current
                    ? const Icon(Icons.check, size: 16, color: AppColors.white)
                    : null,
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                steps[i].label,
                style: AppTextStyles.caption.copyWith(
                  color: i <= current
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (i < steps.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: i < current ? AppColors.black : AppColors.border,
              ),
            ),
        ],
      ],
    );
  }
}
