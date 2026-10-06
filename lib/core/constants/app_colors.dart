import 'package:flutter/material.dart';

/// Цветовая палитра приложения, снятая с макетов Figma.
/// Значения предварительные: сверить с Figma Dev Mode.
/// Во всём проекте цвета берутся ТОЛЬКО отсюда, без Color(0x...) в экранах.
class AppColors {
  AppColors._();

  // Фоны
  static const Color background = Color(0xFFCFE6FA); // голубой фон экранов
  static const Color surface = Color(0xFFFFFFFF); // карточки, шапка, навигация
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // Текст
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF6E6E73);
  static const Color textHint = Color(0xFFA0A0A5);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Фон картинки-заглушки
  static const Color imagePlaceholder = Color(0xFFF1F3F6);

  // Обводки и разделители
  static const Color border = Color(0xFFD9D9D9);
  static const Color divider = Color(0xFFE5E5EA);

  // Бренд
  static const Color logoRed = Color(0xFFD7262B);

  // Состояния сообщений
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF2A900);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF1E6FD9);

  // Статусы заказов (чипы в истории заказов)
  static const Color statusNewBackground = Color(0xFFE3DEFF);
  static const Color statusNewText = Color(0xFF5B4BC4);
  static const Color statusInTransitBackground = Color(0xFFFFF1B8);
  static const Color statusInTransitText = Color(0xFF8A6D00);
  static const Color statusDeliveredBackground = Color(0xFFD4F5D0);
  static const Color statusDeliveredText = Color(0xFF2E7D32);

  // Нижняя навигация
  static const Color navActive = Color(0xFF000000);
  static const Color navInactive = Color(0xFF8E8E93);
}
