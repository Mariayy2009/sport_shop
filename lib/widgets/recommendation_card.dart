import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../models/recommended_product.dart';
import 'app_card.dart';
import 'product_image.dart';

/// Рекомендованный товар (экран ии5): фото, название, причина, цена,
/// круглая кнопка «+» (или галочка, если уже в корзине).
class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.item,
    required this.isInCart,
    required this.onTap,
    required this.onAdd,
  });

  final RecommendedProduct item;
  final bool isInCart;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSizes.s),
      child: Row(
        children: [
          ProductImage(
            imageUrl: item.product.imageUrl,
            width: 56,
            height: 56,
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
                Text(
                  item.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppSizes.xxs),
                Text(
                  Formatters.price(item.product.price),
                  style: AppTextStyles.price.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.s),
          Tooltip(
            message: isInCart ? 'Уже в корзине' : 'Добавить в корзину',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onAdd,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isInCart ? AppColors.success : AppColors.black,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isInCart ? Icons.check : Icons.add,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
