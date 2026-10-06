import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../theme/app_text_styles.dart';

/// ВРЕМЕННЫЙ экран этапов 1–5.
/// Показывает дизайн-токены, чтобы сверить их с Figma.
/// Удалим, когда все экраны будут сверстаны.
class StagePlaceholderScreen extends StatelessWidget {
  const StagePlaceholderScreen({super.key, required this.routeName});

  final String routeName;

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          children: [
            const Text('Этап 1: структура проекта',
                style: AppTextStyles.screenTitle),
            const SizedBox(height: AppSizes.s),
            Text('Маршрут: $routeName', style: AppTextStyles.bodySecondary),
            const SizedBox(height: AppSizes.xl),
            const Text('Палитра', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSizes.s),
            const Wrap(
              spacing: AppSizes.s,
              runSpacing: AppSizes.s,
              children: [
                _ColorSample(name: 'background', color: AppColors.background),
                _ColorSample(name: 'surface', color: AppColors.surface),
                _ColorSample(name: 'black', color: AppColors.black),
                _ColorSample(name: 'logoRed', color: AppColors.logoRed),
                _ColorSample(
                    name: 'новый', color: AppColors.statusNewBackground),
                _ColorSample(
                    name: 'в пути', color: AppColors.statusInTransitBackground),
                _ColorSample(
                    name: 'доставлен',
                    color: AppColors.statusDeliveredBackground),
                _ColorSample(name: 'error', color: AppColors.error),
              ],
            ),
            const SizedBox(height: AppSizes.xl),
            const Text('Кнопки', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSizes.s),
            ElevatedButton(
              onPressed: () => _showMessage(context, 'Основная кнопка работает'),
              child: const Text('Войти'),
            ),
            const SizedBox(height: AppSizes.s),
            OutlinedButton(
              onPressed: () =>
                  _showMessage(context, 'Вторичная кнопка работает'),
              child: const Text('Сбросить все'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorSample extends StatelessWidget {
  const _ColorSample({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppSizes.radiusS),
            border: Border.all(color: AppColors.border),
          ),
        ),
        const SizedBox(height: AppSizes.xs),
        Text(name, style: AppTextStyles.caption),
      ],
    );
  }
}
