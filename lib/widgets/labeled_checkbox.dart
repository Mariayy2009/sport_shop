import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';

/// Чекбокс с подписью: «Запомнить меня», «I agree to the processing...».
/// Нажатие на текст тоже переключает чекбокс.
class LabeledCheckbox extends StatelessWidget {
  const LabeledCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.hasError = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  /// Красная рамка, если обязательный чекбокс не отмечен.
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = hasError ? AppColors.error : AppColors.black;
    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusS),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: (checked) => onChanged(checked ?? false),
                activeColor: AppColors.black,
                checkColor: AppColors.white,
                side: BorderSide(color: borderColor, width: 1.5),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: AppSizes.s),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.bodySecondary.copyWith(
                  color: hasError ? AppColors.error : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
