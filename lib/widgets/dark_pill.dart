import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';

/// Переключатель-«таблетка» для тёмных экранов камеры: выбранный —
/// белый с чёрным текстом, остальные — полупрозрачные с белым.
class DarkPill extends StatelessWidget {
  const DarkPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.highlighted = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Зелёная рамка — например, рекомендуемый размер.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.white : const Color(0x40FFFFFF),
        shape: StadiumBorder(
          side: highlighted
              ? const BorderSide(color: AppColors.success, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.m,
              vertical: AppSizes.xs,
            ),
            child: Text(
              label,
              style: AppTextStyles.bodySecondary.copyWith(
                color: selected ? AppColors.black : AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
