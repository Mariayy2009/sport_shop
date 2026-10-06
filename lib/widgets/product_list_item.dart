import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../models/product.dart';
import 'app_card.dart';
import 'product_image.dart';

/// Строка товара в каталоге: фото, название, категория, размеры, цена
/// и кнопка «В корзину».
class ProductListItem extends StatelessWidget {
  const ProductListItem({
    super.key,
    required this.product,
    required this.onTap,
    required this.onAddToCart,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  String get _sizesText {
    final List<String> sizes = product.availableSizes;
    if (sizes.isEmpty) return 'Без размера';
    if (sizes.length <= 3) return 'Размеры: ${sizes.join(', ')}';
    return 'Размеры: ${sizes.first}–${sizes.last}';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSizes.s),
      child: Row(
        children: [
          ProductImage(
            imageUrl: product.imageUrl,
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
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSizes.xxs),
                Text(
                  '${product.categoryName ?? ''} · ${product.sportName ?? ''}',
                  style: AppTextStyles.caption,
                ),
                Text(
                  product.isAvailable ? _sizesText : 'Нет в наличии',
                  style: AppTextStyles.caption.copyWith(
                    color: product.isAvailable
                        ? AppColors.textSecondary
                        : AppColors.error,
                  ),
                ),
                const SizedBox(height: AppSizes.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        Formatters.price(product.price),
                        style: AppTextStyles.price,
                      ),
                    ),
                    _SmallPillButton(
                      text: 'В корзину',
                      enabled: product.isAvailable,
                      onTap: onAddToCart,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallPillButton extends StatelessWidget {
  const _SmallPillButton({
    required this.text,
    required this.enabled,
    required this.onTap,
  });

  final String text;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppColors.black : AppColors.border,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        // Даже для недоступного товара нажатие объясняет причину.
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.m,
            vertical: AppSizes.xs + 2,
          ),
          child: Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: enabled ? AppColors.textOnDark : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
