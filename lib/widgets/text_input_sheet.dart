import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import 'custom_button.dart';

/// Нижняя форма с одним текстовым полем: вопрос о товаре, ответ магазина.
/// Возвращает введённый текст или null, если форму закрыли.
class TextInputSheet extends StatefulWidget {
  const TextInputSheet({
    super.key,
    required this.title,
    required this.hint,
    required this.buttonText,
    required this.maxLength,
    this.subtitle,
    this.initialText = '',
  });

  final String title;
  final String? subtitle;
  final String hint;
  final String buttonText;
  final int maxLength;
  final String initialText;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String hint,
    required String buttonText,
    required int maxLength,
    String? subtitle,
    String initialText = '',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusL)),
      ),
      builder: (_) => TextInputSheet(
        title: title,
        subtitle: subtitle,
        hint: hint,
        buttonText: buttonText,
        maxLength: maxLength,
        initialText: initialText,
      ),
    );
  }

  @override
  State<TextInputSheet> createState() => _TextInputSheetState();
}

class _TextInputSheetState extends State<TextInputSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String text = _controller.text.trim();
    if (text.length < 3) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSizes.l,
          0,
          AppSizes.l,
          AppSizes.l + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: AppTextStyles.sectionTitle),
            if (widget.subtitle != null) ...[
              const SizedBox(height: AppSizes.xxs),
              Text(widget.subtitle!, style: AppTextStyles.bodySecondary),
            ],
            const SizedBox(height: AppSizes.m),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              maxLength: widget.maxLength,
              textCapitalization: TextCapitalization.sentences,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
                errorText: _showError ? 'Напишите хотя бы пару слов' : null,
                filled: true,
                fillColor: AppColors.background,
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.s),
            CustomButton(text: widget.buttonText, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
