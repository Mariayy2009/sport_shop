import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import '../models/enums.dart';

/// Чип статуса заказа: «Новый», «В пути», «Доставлен».
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color text) = switch (status) {
      OrderStatus.newOrder =>
        (AppColors.statusNewBackground, AppColors.statusNewText),
      OrderStatus.inTransit =>
        (AppColors.statusInTransitBackground, AppColors.statusInTransitText),
      OrderStatus.delivered =>
        (AppColors.statusDeliveredBackground, AppColors.statusDeliveredText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.s,
        vertical: AppSizes.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.caption.copyWith(
          color: text,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
