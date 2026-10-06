import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Логотип SPORT из шапки.
/// Берётся из assets/images/logo.png (экспорт из Figma).
/// Пока файла нет, рисуется текстовая версия, чтобы экран не ломался.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 28});

  static const String assetPath = 'assets/images/logo.png';

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => _TextLogo(height: height),
    );
  }
}

class _TextLogo extends StatelessWidget {
  const _TextLogo({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.logoRed,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: AppColors.black, width: 1.5),
      ),
      child: Text(
        'SPORT',
        style: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: height * 0.55,
          height: 1,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: 1,
          color: AppColors.white,
        ),
      ),
    );
  }
}
