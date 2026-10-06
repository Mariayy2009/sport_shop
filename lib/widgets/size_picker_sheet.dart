import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import '../models/product.dart';
import 'custom_button.dart';
import 'size_selector.dart';

/// Нижняя панель «Выберите размер» перед добавлением в корзину.
class SizePickerSheet extends StatefulWidget {
  const SizePickerSheet({super.key, required this.product, this.initialSize});

  final Product product;
  final String? initialSize;

  /// Возвращает выбранный размер или null, если панель закрыли.
  static Future<String?> show(
    BuildContext context,
    Product product, {
    String? initialSize,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusL),
        ),
      ),
      builder: (_) =>
          SizePickerSheet(product: product, initialSize: initialSize),
    );
  }

  @override
  State<SizePickerSheet> createState() => _SizePickerSheetState();
}

class _SizePickerSheetState extends State<SizePickerSheet> {
  late String? _selected = widget.initialSize;
  bool _showError = false;

  void _confirm() {
    if (_selected == null) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(_selected);
  }

  @override
  Widget build(BuildContext context) {
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
            const Text('Выберите размер', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSizes.xs),
            Text(widget.product.name, style: AppTextStyles.bodySecondary),
            const SizedBox(height: AppSizes.l),
            SizeSelector(
              sizes: widget.product.availableSizes,
              selected: _selected,
              hasError: _showError,
              onSelected: (size) => setState(() {
                _selected = size;
                _showError = false;
              }),
            ),
            if (_showError) ...[
              const SizedBox(height: AppSizes.s),
              const Text(
                'Выберите размер, чтобы продолжить',
                style: AppTextStyles.fieldError,
              ),
            ],
            const SizedBox(height: AppSizes.xl),
            CustomButton(text: 'Добавить в корзину', onPressed: _confirm),
          ],
        ),
      ),
    );
  }
}
