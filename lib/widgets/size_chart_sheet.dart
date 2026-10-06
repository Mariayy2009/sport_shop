import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import '../models/product.dart';

/// Таблица размеров («Прикреплённые файлы» в карточке товара).
class SizeChartSheet extends StatelessWidget {
  const SizeChartSheet({super.key, required this.product});

  final Product product;

  static Future<void> show(BuildContext context, Product product) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusL),
        ),
      ),
      builder: (_) => SizeChartSheet(product: product),
    );
  }

  static const List<List<String>> _clothing = [
    ['Размер', 'Рост, см', 'Обхват груди, см'],
    ['XS', '155–160', '80–84'],
    ['S', '160–165', '84–88'],
    ['M', '165–170', '88–92'],
    ['L', '170–176', '92–96'],
    ['XL', '176–182', '96–100'],
    ['XXL', '182–188', '100–104'],
  ];

  static const List<List<String>> _shoes = [
    ['Размер (EU)', 'Длина стопы, см'],
    ['36', '23,0'],
    ['37', '23,5'],
    ['38', '24,0'],
    ['39', '25,0'],
    ['40', '25,5'],
    ['41', '26,0'],
    ['42', '27,0'],
    ['43', '27,5'],
    ['44', '28,0'],
    ['45', '29,0'],
  ];

  @override
  Widget build(BuildContext context) {
    final bool isShoes = product.categoryName == 'Обувь';
    final List<List<String>> rows = isShoes ? _shoes : _clothing;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.l,
          0,
          AppSizes.l,
          AppSizes.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Таблица размеров', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSizes.xs),
            Text(
              product.requiresSize
                  ? 'В наличии: ${product.availableSizes.join(', ')}'
                  : 'Для этого товара выбор размера не требуется',
              style: AppTextStyles.bodySecondary,
            ),
            if (product.requiresSize && !_hasStandardTable(isShoes)) ...[
              const SizedBox(height: AppSizes.s),
              const Text(
                'Размеры этого товара указаны в характеристиках производителя.',
                style: AppTextStyles.caption,
              ),
            ],
            const SizedBox(height: AppSizes.l),
            if (product.requiresSize && _hasStandardTable(isShoes))
              Table(
                border: TableBorder.all(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppSizes.radiusS),
                ),
                children: [
                  for (int i = 0; i < rows.length; i++)
                    TableRow(
                      decoration: BoxDecoration(
                        color: i == 0 ? AppColors.imagePlaceholder : null,
                      ),
                      children: [
                        for (final String cell in rows[i])
                          Padding(
                            padding: const EdgeInsets.all(AppSizes.s),
                            child: Text(
                              cell,
                              textAlign: TextAlign.center,
                              style: i == 0
                                  ? AppTextStyles.bodySecondary
                                      .copyWith(fontWeight: FontWeight.w600)
                                  : AppTextStyles.body,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Стандартная таблица подходит, если размеры товара буквенные
  /// (одежда) или это обувь.
  bool _hasStandardTable(bool isShoes) {
    if (isShoes) return true;
    const Set<String> letters = {'XS', 'S', 'M', 'L', 'XL', 'XXL'};
    return product.availableSizes.every(letters.contains);
  }
}
