import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

enum ButtonVariant {
  /// Чёрная «таблетка»: «Войти», «Применить», «Далее».
  primary,

  /// Белая с обводкой: «Сбросить все», «Назад».
  secondary,
}

/// Кнопка приложения. Стили берутся из AppTheme.
/// Пока идёт загрузка, кнопка показывает индикатор и не нажимается.
class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.isLoading = false,
  });

  final String text;
  final VoidCallback onPressed;
  final ButtonVariant variant;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final bool isPrimary = variant == ButtonVariant.primary;
    final Widget child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isPrimary ? AppColors.white : AppColors.black,
            ),
          )
        : Text(text);
    final VoidCallback? action = isLoading ? null : onPressed;

    return isPrimary
        ? ElevatedButton(onPressed: action, child: child)
        : OutlinedButton(onPressed: action, child: child);
  }
}
