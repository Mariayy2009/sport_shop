import 'package:flutter/material.dart';

import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';

/// Строка итогов: «Итого ......... 6 500 ₸».
class SummaryRow extends StatelessWidget {
  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle =
        isTotal ? AppTextStyles.sectionTitle : AppTextStyles.bodySecondary;
    final TextStyle valueStyle =
        isTotal ? AppTextStyles.priceLarge : AppTextStyles.body;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}
