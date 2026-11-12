import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Звезда и оценка товара: «★ 4,8».
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating});

  final double? rating;

  @override
  Widget build(BuildContext context) {
    final double? value = rating;
    if (value == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 15, color: AppColors.star),
        const SizedBox(width: 2),
        Text(
          value.toStringAsFixed(1).replaceAll('.', ','),
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
