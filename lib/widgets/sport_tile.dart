import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/constants/sport_visuals.dart';
import '../core/theme/app_text_styles.dart';

/// Плитка-фото вида спорта на главной (сетка 2 × N из Figma).
class SportTile extends StatelessWidget {
  const SportTile({super.key, required this.sportName, required this.onTap});

  final String sportName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final SportVisual visual = SportVisuals.of(sportName);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              visual.imagePath,
              fit: BoxFit.cover,
              // Пока фото нет — большая иконка вида спорта.
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(visual.icon, size: 56, color: AppColors.textHint),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.s,
                  AppSizes.l,
                  AppSizes.s,
                  AppSizes.s,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.black.withValues(alpha: 0),
                      AppColors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
                child: Text(
                  sportName,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
