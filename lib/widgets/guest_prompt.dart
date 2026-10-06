import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/constants/app_strings.dart';
import '../core/routes/app_routes.dart';
import '../core/theme/app_text_styles.dart';
import 'custom_button.dart';

/// Заглушка для гостя на разделах, доступных только покупателю
/// (AI-подбор, корзина, профиль): объясняет, почему раздел недоступен,
/// и предлагает войти или зарегистрироваться.
class GuestPrompt extends StatelessWidget {
  const GuestPrompt({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.lock_outline,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(icon, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: AppSizes.l),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: AppSizes.s),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: AppSizes.xl),
            CustomButton(
              text: AppStrings.loginButton,
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
            ),
            const SizedBox(height: AppSizes.m),
            CustomButton(
              text: AppStrings.registrationButton,
              variant: ButtonVariant.secondary,
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.registration),
            ),
          ],
        ),
      ),
    );
  }
}
