import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import 'custom_button.dart';

/// Понятное пустое состояние: пустая корзина, нет заказов, ничего не найдено.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionText,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSizes.l),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSizes.s),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
            ],
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: AppSizes.xl),
              CustomButton(text: actionText!, onPressed: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}
