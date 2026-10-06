import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import 'app_text_field.dart';

/// Выпадающий список в стиле полей Figma («Категория», «Вид спорта»).
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.validator,
    this.hint,
  });

  final String label;
  final List<DropdownMenuItem<T>> items;
  final T? value;
  final ValueChanged<T?> onChanged;
  final FormFieldValidator<T>? validator;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSizes.s, bottom: AppSizes.xs),
          child: Text(label, style: AppTextStyles.fieldLabel),
        ),
        DropdownButtonFormField<T>(
          // Ключ пересоздаёт поле, когда значение меняют извне (сброс фильтров).
          key: ValueKey<Object?>(value),
          initialValue: value,
          items: items,
          onChanged: onChanged,
          validator: validator,
          isExpanded: true,
          style: AppTextStyles.body,
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          icon: const Icon(Icons.keyboard_arrow_down),
          decoration: AppTextField.buildDecoration(hint: hint),
        ),
      ],
    );
  }
}
