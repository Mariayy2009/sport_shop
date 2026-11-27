import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/routes/app_routes.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/cart_actions.dart';
import '../core/utils/formatters.dart';
import '../core/utils/product_actions.dart';
import '../models/item_options.dart';
import '../models/product.dart';
import '../state/cart_state.dart';
import '../state/compare_state.dart';
import '../state/favorites_state.dart';
import 'app_card.dart';
import 'low_stock_chip.dart';
import 'product_image.dart';
import 'rating_badge.dart';

/// Карточка товара для сетки каталога и избранного:
/// фото, избранное и сравнение поверх фото, рейтинг, цена, «в корзину».
class ProductGridCard extends StatelessWidget {
  const ProductGridCard({super.key, required this.product, this.variant});

  final Product product;

  /// Карточка отдельного варианта (цвета, модели): своё фото и подпись.
  /// В карточке товара варианты по-прежнему переключаются.
  final ProductVariant? variant;

  /// Соотношение сторон ячейки сетки под эту карточку.
  static const double aspectRatio = 0.6;

  @override
  Widget build(BuildContext context) {
    final bool isFavorite = context.watch<FavoritesState>().contains(product.id);
    final bool inCompare = context.watch<CompareState>().contains(product.id);
    final bool inCart = context.watch<CartState>().containsProduct(product.id);

    return AppCard(
      padding: const EdgeInsets.all(AppSizes.s),
      onTap: () => Navigator.of(context).pushNamed(
            AppRoutes.product,
            arguments: ProductArgs(product.id!, variant: variant?.name),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ProductImage(
                    imageUrl: variant?.image ?? product.imageUrl,
                    borderRadius: AppSizes.radiusS,
                  ),
                ),
                Positioned(
                  left: AppSizes.xs,
                  bottom: AppSizes.xs,
                  child: LowStockChip(product: product),
                ),
                Positioned(
                  top: AppSizes.xs,
                  right: AppSizes.xs,
                  child: _OverlayButton(
                    tooltip: isFavorite ? 'Убрать из избранного' : 'В избранное',
                    icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? AppColors.favorite : AppColors.textPrimary,
                    onTap: () => ProductActions.toggleFavorite(context, product),
                  ),
                ),
                Positioned(
                  top: AppSizes.xs + 36,
                  right: AppSizes.xs,
                  child: _OverlayButton(
                    tooltip: inCompare ? 'Убрать из сравнения' : 'Сравнить',
                    icon: Icons.compare_arrows,
                    color: inCompare ? AppColors.accent : AppColors.textPrimary,
                    onTap: () => ProductActions.toggleCompare(context, product),
                  ),
                ),
                if (!product.isAvailable)
                  Positioned(
                    left: AppSizes.xs,
                    bottom: AppSizes.xs,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.s,
                        vertical: AppSizes.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                      ),
                      child: Text(
                        'Нет в наличии',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.s),
          Row(
            children: [
              Expanded(
                child: Text(
                  product.brand ?? product.sportName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ),
              RatingBadge(rating: product.rating),
            ],
          ),
          const SizedBox(height: AppSizes.xxs),
          SizedBox(
            height: 38,
            child: Text(
              variant == null ? product.name : '${product.name}, ${variant!.name.toLowerCase()}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Formatters.price(product.price),
                    style: AppTextStyles.price,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.xs),
              Tooltip(
                message: inCart ? 'Уже в корзине' : 'В корзину',
                child: Material(
                  color: inCart
                      ? AppColors.success
                      : (product.isAvailable ? AppColors.black : AppColors.border),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () =>
                        CartActions.addToCart(context, product, variant: variant?.name),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        inCart ? Icons.check : Icons.add_shopping_cart,
                        size: 18,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.white.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}
