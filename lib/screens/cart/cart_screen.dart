import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/errors/app_exception.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/app_messages.dart';
import '../../core/utils/formatters.dart';
import '../../models/cart_item.dart';
import '../../models/enums.dart';
import '../../models/user_sizes.dart';
import '../../state/cart_state.dart';
import '../../state/order_state.dart';
import '../../state/profile_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/cart_item_tile.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/screen_title_bar.dart';
import '../../widgets/summary_row.dart';
import '../../widgets/what_else_section.dart';

/// Корзина (фрейм Figma «корзина»).
class CartScreen extends StatelessWidget {
  const CartScreen({super.key, required this.onGoShopping});

  final VoidCallback onGoShopping;

  Future<void> _changeQuantity(
    BuildContext context,
    CartItem item,
    int quantity,
  ) async {
    if (quantity < 1) {
      await _remove(context, item);
      return;
    }
    try {
      await context.read<CartState>().updateQuantity(item, quantity);
    } on AppException catch (error) {
      if (context.mounted) AppMessages.showWarning(context, error.message);
    }
  }

  Future<void> _remove(BuildContext context, CartItem item) async {
    final CartState cart = context.read<CartState>();
    await cart.remove(item);
    if (!context.mounted) return;
    AppMessages.show(
      context,
      'Товар удалён из корзины',
      actionLabel: 'Вернуть',
      onAction: () => cart.add(
        item.product,
        size: item.selectedSize,
        quantity: item.quantity,
      ),
    );
  }

  Future<void> _clear(BuildContext context) async {
    final bool confirmed = await AppMessages.showConfirmDialog(
      context,
      title: 'Очистить корзину?',
      message: 'Все товары будут удалены из корзины.',
      confirmText: 'Очистить',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await context.read<CartState>().clear();
    if (!context.mounted) return;
    AppMessages.showInfo(context, 'Корзина очищена');
  }

  @override
  Widget build(BuildContext context) {
    final CartState cart = context.watch<CartState>();
    final UserSizes? sizes = context.watch<ProfileState>().sizes;
    final List<CartItem> items = cart.items;

    return Column(
      children: [
        ScreenTitleBar(
          title: 'Корзина',
          showBack: false,
          trailing: items.isEmpty
              ? null
              : TextButton(
                  onPressed: () => _clear(context),
                  child: const Text('Очистить'),
                ),
        ),
        Expanded(child: _buildBody(context, cart, items, sizes)),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    CartState cart,
    List<CartItem> items,
    UserSizes? sizes,
  ) {
    if (cart.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_basket_outlined,
        title: 'Корзина пуста',
        message: 'Добавьте товары из каталога или воспользуйтесь AI-подбором '
            'экипировки',
        actionText: 'Перейти в каталог',
        onAction: onGoShopping,
      );
    }

    final double delivery = OrderState.deliveryPrice(DeliveryMethod.courier);
    // «Что ещё купить?»: вид спорта из профиля или первого товара в корзине.
    final int sportId = sizes?.sportId ?? items.first.product.sportId;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            children: [
              if (cart.unavailable.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.s),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error),
                            const SizedBox(width: AppSizes.s),
                            Expanded(
                              child: Text(
                                'Часть товаров сейчас нельзя купить: их сняли '
                                'с продажи или раскупили. В заказ они не попадут',
                                style: AppTextStyles.body
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () async {
                            for (final CartItem item in cart.unavailable) {
                              await cart.remove(item);
                            }
                          },
                          child: const Text('Убрать недоступные товары'),
                        ),
                      ],
                    ),
                  ),
                ),
              // «Выбрать все» — купить можно только отмеченное.
              InkWell(
                onTap: () => cart.selectAll(!cart.allSelected),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.s),
                  child: Row(
                    children: [
                      Checkbox(
                        value: cart.allSelected,
                        activeColor: AppColors.black,
                        onChanged: (value) => cart.selectAll(value ?? false),
                      ),
                      Expanded(
                        child: Text('Выбрать все', style: AppTextStyles.body),
                      ),
                      Flexible(
                        child: Text(
                          'Выбрано: ${cart.selectedItems.length} из ${items.length}',
                          textAlign: TextAlign.right,
                          style: AppTextStyles.caption,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (final CartItem item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.s),
                  child: CartItemTile(
                    item: item,
                    selected: cart.isSelected(item),
                    onSelectedChanged:
                        cart.isAvailable(item) ? (_) => cart.toggle(item) : null,
                    onTap: () => Navigator.of(context).pushNamed(
                      AppRoutes.product,
                      arguments: item.product.id,
                    ),
                    onDecrease: () =>
                        _changeQuantity(context, item, item.quantity - 1),
                    onIncrease: () =>
                        _changeQuantity(context, item, item.quantity + 1),
                    onRemove: () => _remove(context, item),
                  ),
                ),
              WhatElseSection(
                sportId: sportId,
                experienceYears: sizes?.experienceYears ?? 0,
                excludeProductIds: cart.productIds,
              ),
              const SizedBox(height: AppSizes.l),
              AppCard(
                child: Column(
                  children: [
                    SummaryRow(
                      label: 'Товары к заказу (${cart.selectedQuantity})',
                      value: Formatters.price(cart.selectedTotal),
                    ),
                    SummaryRow(
                      label: 'Доставка курьером',
                      value: Formatters.price(delivery),
                    ),
                    const Divider(),
                    SummaryRow(
                      label: 'Итого',
                      value: Formatters.price(cart.selectedTotal + delivery),
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.l,
            AppSizes.s,
            AppSizes.l,
            AppSizes.s,
          ),
          child: CustomButton(
            text: cart.selectedItems.isEmpty
                ? 'Отметьте товары для заказа'
                : 'Оформить заказ (${cart.selectedQuantity} шт.)',
            onPressed: cart.selectedItems.isEmpty
                ? null
                : () => Navigator.of(context).pushNamed(AppRoutes.checkout),
          ),
        ),
      ],
    );
  }
}
