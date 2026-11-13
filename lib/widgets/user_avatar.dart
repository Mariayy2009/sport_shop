import 'dart:io';

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

/// Круглый аватар: фото пользователя, а без него — первая буква имени.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.imagePath,
    this.size = 40,
    this.borderWidth = 0,
  });

  final String name;
  final String? imagePath;
  final double size;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final String trimmed = name.trim();
    final Widget letter = Center(
      child: Text(
        trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: AppColors.accentDark,
        ),
      ),
    );
    final String? path = imagePath;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        shape: BoxShape.circle,
        border: borderWidth == 0
            ? null
            : Border.all(color: AppColors.accent, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: path == null
          ? letter
          : Image.file(
              File(path),
              fit: BoxFit.cover,
              // Файл могли удалить вне приложения — показываем букву.
              errorBuilder: (context, error, stackTrace) => letter,
            ),
    );
  }
}
