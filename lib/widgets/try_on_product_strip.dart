import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import '../models/product.dart';
import 'product_image.dart';

/// Лента товаров для примерки: переключение вещи одним нажатием.
/// [dark] — оформление поверх камеры.
class TryOnProductStrip extends StatelessWidget {
  const TryOnProductStrip({
    super.key,
    required this.products,
    required this.selectedId,
    required this.onSelected,
    this.dark = false,
  });

  final List<Product> products;
  final int? selectedId;
  final ValueChanged<Product> onSelected;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: dark ? AppSizes.screenPadding : 0),
        itemCount: products.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppSizes.s),
        itemBuilder: (context, index) {
          final Product product = products[index];
          final bool isSelected = product.id == selectedId;
          return Semantics(
            button: true,
            selected: isSelected,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              onTap: () => onSelected(product),
              child: Container(
                width: 88,
                padding: const EdgeInsets.all(AppSizes.xs),
                decoration: BoxDecoration(
                  color: dark
                      ? AppColors.black.withValues(alpha: 0.55)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accent
                        : (dark ? Colors.transparent : AppColors.border),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ProductImage(
                        imageUrl: product.imageUrl,
                        width: double.infinity,
                        borderRadius: AppSizes.radiusS,
                      ),
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        color: dark ? AppColors.white : AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
