import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../models/cart_item.dart';
import 'app_card.dart';
import 'product_image.dart';
import 'quantity_stepper.dart';

/// Позиция корзины: фото, название, размер, цена, количество, удаление.
class CartItemTile extends StatelessWidget {
  const CartItemTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  final CartItem item;
  final VoidCallback onTap;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSizes.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductImage(
            imageUrl: item.product.imageUrl,
            width: 72,
            height: 72,
            borderRadius: AppSizes.radiusS,
          ),
          const SizedBox(width: AppSizes.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSizes.xxs),
                Text(
                  item.selectedSize == null
                      ? Formatters.price(item.product.price)
                      : 'Размер ${item.selectedSize} · '
                          '${Formatters.price(item.product.price)}',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppSizes.s),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        Formatters.price(item.total),
                        style: AppTextStyles.price,
                      ),
                    ),
                    QuantityStepper(
                      quantity: item.quantity,
                      onDecrease: onDecrease,
                      onIncrease: onIncrease,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Удалить',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
