import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../models/cart_item.dart';
import '../models/item_options.dart';
import '../models/product.dart';
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

  /// Почему позицию нельзя купить или о чём предупредить.
  String? get _problem {
    final Product product = item.product;
    if (product.isBlocked) return 'Снят с продажи — удалите из корзины';
    if (product.isPendingReview) return 'На проверке у модератора — пока нельзя купить';
    if (product.sellerInactive) return 'Магазин продавца закрыт — удалите из корзины';
    if (product.stock == 0) return 'Нет в наличии';
    if (product.stock < item.quantity) return 'На складе только ${product.stock} шт.';
    if (product.isLowStock) return 'Мало осталось: ${product.stock} шт.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ItemOptions options = ItemOptions.decode(item.selectedSize);
    // Выбран вариант — показываем его фото (тот цвет, что в корзине).
    final String? image =
        item.product.variantNamed(options.variant)?.image ?? item.product.imageUrl;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSizes.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductImage(
            imageUrl: image,
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
                  options.isEmpty
                      ? Formatters.price(item.product.price)
                      : '${options.label} · '
                          '${Formatters.price(item.product.price)}',
                  style: AppTextStyles.caption,
                ),
                if (_problem case final String problem)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSizes.xxs),
                    child: Text(
                      problem,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
