import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import '../models/exhibit.dart';
import 'product_image.dart';

/// Карточка экспоната в «Зале славы»: фото (со значком, если фото
/// несколько), имя или вещь, достижение или владелец, вид спорта и год.
class ExhibitCard extends StatelessWidget {
  const ExhibitCard({super.key, required this.exhibit, required this.onTap});

  final Exhibit exhibit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(AppSizes.radiusM);
    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ProductImage(
                      imageUrl: exhibit.imageUrl,
                      borderRadius: 0,
                      placeholderIcon: Icons.emoji_events_outlined,
                    ),
                  ),
                  if (exhibit.images.length > 1)
                    Positioned(
                      right: AppSizes.s,
                      top: AppSizes.s,
                      child: _PhotoCount(count: exhibit.images.length),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exhibit.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    exhibit.athlete,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySecondary,
                  ),
                  Text(
                    [exhibit.sportTitle, exhibit.year].whereType<String>().join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Значок «несколько фото» на карточке.
class _PhotoCount extends StatelessWidget {
  const _PhotoCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.s, vertical: AppSizes.xxs),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_library_outlined, size: 14, color: AppColors.white),
          const SizedBox(width: AppSizes.xxs),
          Text(
            '$count',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
