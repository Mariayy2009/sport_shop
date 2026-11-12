import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';

/// Картинка товара. Поддерживает файлы из assets и ссылки (облако в дипломе).
/// Если картинки нет — заглушка с иконкой вида спорта, экран не ломается.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.borderRadius = AppSizes.radiusM,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.image_outlined,
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        color: AppColors.imagePlaceholder,
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    final String url = imageUrl ?? '';
    if (url.isEmpty) return _placeholder();
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }
    return Image.asset(
      url,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  /// Заглушка, пока фото товара нет: иконка вида спорта на мягком фоне.
  Widget _placeholder() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double side = constraints.biggest.shortestSide;
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.imagePlaceholder, AppColors.accentSoft],
            ),
          ),
          child: Center(
            child: Icon(
              _iconFor(imageUrl) ?? placeholderIcon,
              color: AppColors.accent.withValues(alpha: 0.55),
              size: side.isFinite ? (side * 0.42).clamp(20, 72) : 28,
            ),
          ),
        );
      },
    );
  }

  /// Иконка по имени файла картинки: «…/football_boots.png» → футбол.
  static const List<(List<String>, IconData)> _icons = [
    (['basketball'], Icons.sports_basketball),
    (['football', 'shin_', 'goalkeeper'], Icons.sports_soccer),
    (['volleyball', 'mikasa', 'knee_'], Icons.sports_volleyball),
    (['running', 'sport_watch'], Icons.directions_run),
    (['swim'], Icons.pool),
    (['boxing', 'hand_wraps', 'mouth_guard'], Icons.sports_mma),
    (['karate'], Icons.sports_martial_arts),
    (['yoga'], Icons.self_improvement),
    (['bottle'], Icons.water_drop_outlined),
    (['gym_', 'kettlebell', 'dumbbells', 'tshirt', 'pants'], Icons.fitness_center),
  ];

  static IconData? _iconFor(String? url) {
    if (url == null) return null;
    final String file = url.split('/').last;
    for (final (List<String> keys, IconData icon) in _icons) {
      if (keys.any(file.contains)) return icon;
    }
    return null;
  }
}
