import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';

/// Вариант ответа-«таблетка» (экран ии3): выбранный — чёрный с галочкой.
class ChoiceOption extends StatelessWidget {
  const ChoiceOption({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.hasError = false,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final Color foreground =
        isSelected ? AppColors.textOnDark : AppColors.textPrimary;
    return Material(
      color: isSelected ? AppColors.black : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: hasError
              ? AppColors.error
              : (isSelected ? AppColors.black : AppColors.border),
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.l,
            vertical: AppSizes.m,
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 20,
                color: foreground,
              ),
              const SizedBox(width: AppSizes.s),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.body.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
