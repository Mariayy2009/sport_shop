import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';

/// Выбор размера: ряд «таблеток» S / M / L или 38 / 39 / 40.
class SizeSelector extends StatelessWidget {
  const SizeSelector({
    super.key,
    required this.sizes,
    required this.selected,
    required this.onSelected,
    this.hasError = false,
  });

  final List<String> sizes;
  final String? selected;
  final ValueChanged<String> onSelected;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSizes.s,
      runSpacing: AppSizes.s,
      children: [
        for (final String size in sizes)
          _SizePill(
            size: size,
            isSelected: size == selected,
            hasError: hasError,
            onTap: () => onSelected(size),
          ),
      ],
    );
  }
}

class _SizePill extends StatelessWidget {
  const _SizePill({
    required this.size,
    required this.isSelected,
    required this.hasError,
    required this.onTap,
  });

  final String size;
  final bool isSelected;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = hasError
        ? AppColors.error
        : (isSelected ? AppColors.black : AppColors.border);
    return Material(
      color: isSelected ? AppColors.black : AppColors.surface,
      shape: StadiumBorder(side: BorderSide(color: borderColor)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 48),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.m),
          alignment: Alignment.center,
          child: Text(
            size,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.textOnDark : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
