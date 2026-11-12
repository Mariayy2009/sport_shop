import 'package:flutter/material.dart';

/// Цветовая палитра приложения: светлый фон, тёмные кнопки
/// и синий акцент для «умных» функций.
/// Во всём проекте цвета берутся ТОЛЬКО отсюда, без Color(0x...) в экранах.
class AppColors {
  AppColors._();

  // Фоны
  static const Color background = Color(0xFFF3F6FB); // голубой фон экранов
  static const Color surface = Color(0xFFFFFFFF); // карточки, шапка, навигация
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF10141C);

  // Текст
  static const Color textPrimary = Color(0xFF10141C);
  static const Color textSecondary = Color(0xFF667085);
  static const Color textHint = Color(0xFF98A2B3);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Фон картинки-заглушки
  static const Color imagePlaceholder = Color(0xFFF4F6F9);

  // Обводки и разделители
  static const Color border = Color(0xFFE1E5EC);
  static const Color divider = Color(0xFFECEFF4);

  // Бренд
  static const Color logoRed = Color(0xFFD7262B);

  // Акцент: ИИ-помощник, активные элементы, подсказки по размеру
  static const Color accent = Color(0xFF2F6BFF);
  static const Color accentSoft = Color(0xFFE6EEFF);
  static const Color accentDark = Color(0xFF1B3FA8);

  // Рейтинг и избранное
  static const Color star = Color(0xFFF5A524);
  static const Color favorite = Color(0xFFE5484D);

  // Тень карточек
  static const Color shadow = Color(0x140F1B33);

  // Состояния сообщений
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF2A900);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF2F6BFF);

  // Статусы заказов (чипы в истории заказов)
  static const Color statusNewBackground = Color(0xFFE3DEFF);
  static const Color statusNewText = Color(0xFF5B4BC4);
  static const Color statusInTransitBackground = Color(0xFFFFF1B8);
  static const Color statusInTransitText = Color(0xFF8A6D00);
  static const Color statusDeliveredBackground = Color(0xFFD4F5D0);
  static const Color statusDeliveredText = Color(0xFF2E7D32);

  // Нижняя навигация
  static const Color navActive = Color(0xFF10141C);
  static const Color navInactive = Color(0xFF98A2B3);
}
