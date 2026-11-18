import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/app_messages.dart';
import '../data/datasources/remote/shop_api_client.dart';
import '../state/data_source_state.dart';
import 'custom_button.dart';

/// Источник каталога: телефон (SQLite) или сервер магазина (PostgreSQL).
class ShopServerSheet extends StatefulWidget {
  const ShopServerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusL)),
      ),
      builder: (_) => const ShopServerSheet(),
    );
  }

  @override
  State<ShopServerSheet> createState() => _ShopServerSheetState();
}

class _ShopServerSheetState extends State<ShopServerSheet> {
  late final TextEditingController _address = TextEditingController(
    text: context.read<DataSourceState>().serverUrl ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final DataSourceState state = context.read<DataSourceState>();
    final NavigatorState navigator = Navigator.of(context);
    setState(() => _error = null);
    final String? error = await state.connect(_address.text);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    AppMessages.showSuccess(context, 'Каталог загружается с сервера');
    navigator.pop();
  }

  Future<void> _useLocal() async {
    final NavigatorState navigator = Navigator.of(context);
    await context.read<DataSourceState>().useLocal();
    if (!mounted) return;
    AppMessages.showInfo(context, 'Каталог загружается с телефона');
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final DataSourceState state = context.watch<DataSourceState>();
    final ShopServerStatus? status = state.status;
    final String current = state.usesServer
        ? 'Сейчас: сервер ${state.serverUrl}'
            '${status?.database == null ? '' : ' · ${status!.database}'}'
        : state.serverUnavailable
            ? 'Сейчас: телефон — сервер ${state.serverUrl} не ответил'
            : 'Сейчас: база на телефоне (SQLite)';
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
            const Text('Сервер магазина', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSizes.xs),
            Text(current, style: AppTextStyles.bodySecondary),
            const SizedBox(height: AppSizes.m),
            const Text(
              'Магазин переходит на базу PostgreSQL. Сейчас через сервер '
              'загружается каталог: виды спорта, категории и товары. '
              'Корзина, заказы и профиль пока хранятся на телефоне.',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: AppSizes.s),
            const Text(
              'Запустите backend\\run_server.bat на компьютере и введите '
              'адрес из его окна. Эмулятор Android: 10.0.2.2:8080.',
              style: AppTextStyles.caption,
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
                hintText: '192.168.1.5:8080',
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
            const SizedBox(height: AppSizes.m),
            CustomButton(
              text: 'Подключить сервер',
              isLoading: state.isBusy,
              onPressed: _connect,
            ),
            if (state.serverUrl != null) ...[
              const SizedBox(height: AppSizes.s),
              CustomButton(
                text: 'Брать данные с телефона',
                variant: ButtonVariant.secondary,
                onPressed: _useLocal,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
