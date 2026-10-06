/// Размеры, отступы и скругления из макетов Figma.
/// В экранах не пишем «магические числа», только эти константы.
class AppSizes {
  AppSizes._();

  // Размер фрейма в Figma (уточнить по Dev Mode)
  static const double designWidth = 360;
  static const double designHeight = 800;

  // Отступы
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double screenPadding = 16;

  // Высоты элементов
  static const double headerHeight = 52;
  static const double bottomNavHeight = 60;
  static const double buttonHeight = 44;
  static const double fieldHeight = 40;

  // Скругления
  static const double radiusS = 8;
  static const double radiusM = 12;
  static const double radiusL = 16;
  static const double radiusPill = 100; // кнопки и поля-«таблетки»

  // Иконки
  static const double iconS = 16;
  static const double iconM = 24;
  static const double iconL = 32;
}
