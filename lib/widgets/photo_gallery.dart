import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import 'product_image.dart';

/// Фото товара или экспоната: одно или несколько, листаются пальцем.
/// Под фото — точки: сколько фото и какое открыто.
class PhotoGallery extends StatefulWidget {
  const PhotoGallery({
    super.key,
    required this.images,
    this.height,
    this.padding = EdgeInsets.zero,
    this.placeholderIcon = Icons.image_outlined,
  });

  final List<String> images;

  /// Высота области фото; null — пропорции 0,85 (чуть выше квадрата).
  final double? height;

  /// Отступ фото от краёв (у товаров — чтобы вещь не упиралась в край).
  final EdgeInsets padding;
  final IconData placeholderIcon;

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _sized(Widget child) => widget.height == null
      ? AspectRatio(aspectRatio: 0.85, child: child)
      : SizedBox(height: widget.height, width: double.infinity, child: child);

  @override
  Widget build(BuildContext context) {
    final List<String?> images =
        widget.images.isEmpty ? const [null] : widget.images;
    return Column(
      children: [
        _sized(
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            child: PageView.builder(
              controller: _controller,
              itemCount: images.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) => ColoredBox(
                color: AppColors.surface,
                child: Padding(
                  padding: widget.padding,
                  child: ProductImage(
                    imageUrl: images[index],
                    width: double.infinity,
                    borderRadius: 0,
                    fit: BoxFit.contain,
                    placeholderIcon: widget.placeholderIcon,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: AppSizes.s),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < images.length; i++)
                GestureDetector(
                  onTap: () => _controller.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _page ? AppColors.black : AppColors.border,
                      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
