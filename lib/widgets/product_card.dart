import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../models/product.dart';
import 'app_card.dart';
import 'product_image.dart';

/// Компактная вертикальная карточка для горизонтальных лент
/// («Что ещё купить?», «С этим товаром покупают»).
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onAdd,
    this.caption,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  /// Короткая подпись под названием, например причина рекомендации.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSizes.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductImage(
              imageUrl: product.imageUrl,
              width: double.infinity,
              height: 90,
              borderRadius: AppSizes.radiusS,
            ),
            const SizedBox(height: AppSizes.s),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySecondary.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (caption != null)
              Text(
                caption!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    Formatters.price(product.price),
                    style: AppTextStyles.price.copyWith(fontSize: 13),
                  ),
                ),
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onAdd,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: AppColors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, size: 18, color: AppColors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
