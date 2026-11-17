import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/app_messages.dart';
import '../state/try_on_controller.dart';
import 'custom_button.dart';

/// Подключение к серверу примерки на ноутбуке: адрес в домашней сети.
class TryOnServerSheet extends StatefulWidget {
  const TryOnServerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusL)),
      ),
      builder: (_) => const TryOnServerSheet(),
    );
  }

  @override
  State<TryOnServerSheet> createState() => _TryOnServerSheetState();
}

class _TryOnServerSheetState extends State<TryOnServerSheet> {
  late final TextEditingController _address = TextEditingController(
    text: context.read<TryOnController>().serverUrl ?? '',
  );
  bool _isChecking = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final NavigatorState navigator = Navigator.of(context);
    final TryOnController controller = context.read<TryOnController>();
    setState(() {
      _isChecking = true;
      _error = null;
    });
    final String? error = await controller.setServerUrl(_address.text);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _isChecking = false;
        _error = error;
      });
      return;
    }
    AppMessages.showSuccess(context, 'Сервер примерки подключён');
    navigator.pop();
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
            const Text('Сервер примерки', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSizes.xs),
            const Text(
              'Нейросеть работает на вашем ноутбуке — бесплатно и без '
              'интернета. Телефон отправляет ей фото по домашней сети.',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: AppSizes.m),
            const Text(
              '1. На ноутбуке запустите run_server.bat из папки tryon_server.\n'
              '2. В окне сервера появится строка «Адрес для приложения» — '
              'например, http://192.168.1.5:8000.\n'
              '3. Подключите телефон к той же сети Wi-Fi и введите '
              'этот адрес ниже.',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: AppSizes.m),
            TextField(
              controller: _address,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _connect(),
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: '192.168.1.5:8000',
                hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
                errorText: _error,
                errorMaxLines: 4,
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
              'На эмуляторе Android адрес ноутбука — 10.0.2.2:8000.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSizes.m),
            CustomButton(
              text: 'Подключить',
              isLoading: _isChecking,
              onPressed: _connect,
            ),
          ],
        ),
      ),
    );
  }
}
