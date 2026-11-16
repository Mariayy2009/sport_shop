import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import '../models/exhibit.dart';
import 'product_image.dart';

/// Плашка источника экспоната: «КНУС» или «Казахстан».
class ExhibitSourceBadge extends StatelessWidget {
  const ExhibitSourceBadge({super.key, required this.source});

  final ExhibitSource source;

  @override
  Widget build(BuildContext context) {
    final bool isKnus = source == ExhibitSource.knus;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.s, vertical: AppSizes.xxs),
      decoration: BoxDecoration(
        color: isKnus ? AppColors.accent : AppColors.black,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Text(
        source.label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Карточка экспоната в «Зале славы»: фото с плашкой источника,
/// что за вещь, чья она, вид спорта и год.
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
                  Positioned(
                    left: AppSizes.s,
                    top: AppSizes.s,
                    child: ExhibitSourceBadge(source: exhibit.source),
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
