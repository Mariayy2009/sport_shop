import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/constants/sport_visuals.dart';
import '../core/theme/app_text_styles.dart';

/// Плитка выбора вида спорта (экран ии2): иконка в круге + название.
class SportOptionTile extends StatelessWidget {
  const SportOptionTile({
    super.key,
    required this.sportName,
    required this.isSelected,
    required this.onTap,
  });

  final String sportName;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color foreground =
        isSelected ? AppColors.textOnDark : AppColors.textPrimary;
    return Material(
      color: isSelected ? AppColors.black : AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: foreground, width: 1.5),
              ),
              child: Icon(
                isSelected ? Icons.check : SportVisuals.of(sportName).icon,
                color: foreground,
                size: 22,
              ),
            ),
            const SizedBox(height: AppSizes.s),
            Text(
              sportName,
              style: AppTextStyles.body.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
