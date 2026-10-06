import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';

/// Картинка товара. Поддерживает файлы из assets и ссылки (облако в дипломе).
/// Если картинки нет — серая заглушка с иконкой, экран не ломается.
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

  Widget _placeholder() {
    return Center(
      child: Icon(placeholderIcon, color: AppColors.textHint, size: 28),
    );
  }
}
