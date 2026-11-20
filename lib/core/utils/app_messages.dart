import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../theme/app_text_styles.dart';

/// Тип информационного сообщения: своя иконка и цвет.
enum MessageType {
  success(Icons.check_circle_outline, AppColors.success),
  error(Icons.error_outline, AppColors.error),
  warning(Icons.warning_amber_rounded, AppColors.warning),
  info(Icons.info_outline, AppColors.info);

  const MessageType(this.icon, this.color);

  final IconData icon;
  final Color color;
}

/// Все сообщения пользователю в одном стиле:
/// SnackBar — успех, ошибка, предупреждение, информация;
/// AlertDialog — подтверждение действия и недоступное действие.
class AppMessages {
  AppMessages._();

  static void show(
    BuildContext context,
    String message, {
    MessageType type = MessageType.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: Duration(seconds: type == MessageType.error ? 4 : 3),
        // С кнопкой («Корзина») Flutter по умолчанию держит уведомление,
        // пока его не закроют. Нам нужно, чтобы оно исчезало само.
        persist: false,
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: AppColors.white,
                onPressed: onAction,
              ),
        content: Row(
          children: [
            Icon(type.icon, color: type.color),
            const SizedBox(width: AppSizes.s),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) =>
      show(context, message, type: MessageType.success);

  static void showError(BuildContext context, String message) =>
      show(context, message, type: MessageType.error);

  static void showWarning(BuildContext context, String message) =>
      show(context, message, type: MessageType.warning);

  static void showInfo(BuildContext context, String message) =>
      show(context, message, type: MessageType.info);

  /// Диалог подтверждения. Возвращает true, если пользователь согласился.
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Подтвердить',
    String cancelText = 'Отмена',
    bool isDestructive = false,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
        ),
        title: Text(title, style: AppTextStyles.sectionTitle),
        content: Text(message, style: AppTextStyles.body),
        actions: [
          TextButton(
            style: _dialogButtonStyle(AppColors.textSecondary),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            style: _dialogButtonStyle(
              isDestructive ? AppColors.error : AppColors.textPrimary,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Информационный диалог с одной кнопкой (например, недоступное действие).
  static Future<void> showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'Понятно',
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
        ),
        title: Text(title, style: AppTextStyles.sectionTitle),
        content: Text(message, style: AppTextStyles.body),
        actions: [
          TextButton(
            style: _dialogButtonStyle(AppColors.textPrimary),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  static ButtonStyle _dialogButtonStyle(Color color) {
    return TextButton.styleFrom(
      foregroundColor: color,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.m,
        vertical: AppSizes.s,
      ),
    );
  }
}
