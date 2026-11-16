import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/app_messages.dart';
import '../services/assistant/configurable_assistant_engine.dart';
import 'custom_button.dart';

/// Настройки нейросети помощника: бесплатный ключ Gemini.
/// Возвращает true, если ключ сохранён или удалён.
class AiSettingsSheet extends StatefulWidget {
  const AiSettingsSheet({super.key, required this.provider});

  final AiProvider provider;

  static const String keyPage = 'aistudio.google.com/apikey';

  static Future<bool> show(BuildContext context, AiProvider provider) async {
    final bool? changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusL)),
      ),
      builder: (_) => AiSettingsSheet(provider: provider),
    );
    return changed ?? false;
  }

  @override
  State<AiSettingsSheet> createState() => _AiSettingsSheetState();
}

class _AiSettingsSheetState extends State<AiSettingsSheet> {
  final TextEditingController _key = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String key = _key.text.trim();
    // Ключи Google AI Studio длинные; короткая строка — явно опечатка.
    if (key.length < 20 || key.contains(' ')) {
      setState(() => _showError = true);
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    await context.read<ConfigurableAssistantEngine>().setGeminiKey(key);
    if (!mounted) return;
    AppMessages.showSuccess(context, 'Gemini подключён');
    navigator.pop(true);
  }

  Future<void> _remove() async {
    final NavigatorState navigator = Navigator.of(context);
    await context.read<ConfigurableAssistantEngine>().setGeminiKey(null);
    if (!mounted) return;
    AppMessages.showInfo(context, 'Ключ удалён — помощник работает без нейросети');
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasGemini = widget.provider == AiProvider.gemini;
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
            const Text('Нейросеть помощника', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSizes.xs),
            Text(
              'Сейчас: ${widget.provider.label.toLowerCase()}. '
              'Без нейросети помощник понимает типовые запросы и работает '
              'без интернета. С Gemini он понимает вопросы своими словами.',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: AppSizes.m),
            const Text('Как подключить Gemini бесплатно', style: AppTextStyles.body),
            const SizedBox(height: AppSizes.xs),
            const Text(
              '1. Откройте ${AiSettingsSheet.keyPage} и войдите в аккаунт Google.\n'
              '2. Нажмите «Create API key» и скопируйте ключ.\n'
              '3. Вставьте его ниже. Карта не нужна; у бесплатного '
              'тарифа есть лимит запросов в минуту и в день.',
              style: AppTextStyles.bodySecondary,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: 'https://${AiSettingsSheet.keyPage}'),
                  );
                  if (context.mounted) {
                    AppMessages.showInfo(context, 'Адрес скопирован');
                  }
                },
                child: const Text(
                  'Скопировать адрес страницы',
                  style: TextStyle(color: AppColors.accent),
                ),
              ),
            ),
            TextField(
              controller: _key,
              autocorrect: false,
              enableSuggestions: false,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: hasGemini ? 'Новый ключ вместо текущего' : 'Ключ Gemini',
                hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
                errorText: _showError ? 'Похоже, ключ скопирован не полностью' : null,
                filled: true,
                fillColor: AppColors.background,
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            const Text(
              'Ключ хранится только на этом устройстве. Ваши вопросы, '
              'каталог и параметры профиля (рост, вес, размеры) '
              'отправляются в Google для ответа.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSizes.m),
            CustomButton(text: 'Сохранить ключ', onPressed: _save),
            if (hasGemini)
              Center(
                child: TextButton(
                  onPressed: _remove,
                  child: const Text(
                    'Отключить Gemini',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
