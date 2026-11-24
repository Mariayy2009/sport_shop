import 'package:flutter/material.dart';

import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import '../data/repositories/moderation_repository.dart';
import 'custom_button.dart';

/// Причина и пояснение для предупреждения продавцу или снятия товара.
class WarningSheet extends StatefulWidget {
  const WarningSheet({super.key, required this.title, required this.buttonText});

  final String title;
  final String buttonText;

  /// Возвращает причину и текст или null, если администратор передумал.
  static Future<(WarningReason, String?)?> show(
    BuildContext context, {
    required String title,
    required String buttonText,
  }) =>
      showModalBottomSheet<(WarningReason, String?)>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => WarningSheet(title: title, buttonText: buttonText),
      );

  @override
  State<WarningSheet> createState() => _WarningSheetState();
}

class _WarningSheetState extends State<WarningSheet> {
  WarningReason _reason = WarningReason.forbidden;
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        0,
        AppSizes.screenPadding,
        MediaQuery.of(context).viewInsets.bottom + AppSizes.screenPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSizes.s),
          RadioGroup<WarningReason>(
            groupValue: _reason,
            onChanged: (value) => setState(() => _reason = value ?? _reason),
            child: Column(
              children: [
                for (final WarningReason reason in WarningReason.values)
                  RadioListTile<WarningReason>(
                    value: reason,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(reason.label, style: AppTextStyles.body),
                  ),
              ],
            ),
          ),
          TextField(
            controller: _text,
            maxLength: 300,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Пояснение для продавца (необязательно)',
            ),
          ),
          const SizedBox(height: AppSizes.s),
          CustomButton(
            text: widget.buttonText,
            onPressed: () => Navigator.of(context).pop(
              (_reason, _text.text.trim().isEmpty ? null : _text.text.trim()),
            ),
          ),
        ],
      ),
    );
  }
}
