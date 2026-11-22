import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import 'product_image.dart';

/// Фото экспоната: одно или несколько, листаются пальцем.
/// Под фото — точки: сколько фото и какое открыто.
class ExhibitGallery extends StatefulWidget {
  const ExhibitGallery({super.key, required this.images});

  final List<String> images;

  @override
  State<ExhibitGallery> createState() => _ExhibitGalleryState();
}

class _ExhibitGalleryState extends State<ExhibitGallery> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String?> images =
        widget.images.isEmpty ? const [null] : widget.images;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 0.85,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            child: PageView.builder(
              controller: _controller,
              itemCount: images.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) => ColoredBox(
                color: AppColors.surface,
                child: ProductImage(
                  imageUrl: images[index],
                  width: double.infinity,
                  borderRadius: 0,
                  fit: BoxFit.contain,
                  placeholderIcon: Icons.emoji_events_outlined,
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
