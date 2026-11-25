import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/product.dart';

/// Плашка на фото товара: «Осталось 2 шт.» — товар скоро раскупят.
class LowStockChip extends StatelessWidget {
  const LowStockChip({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    if (!product.isLowStock) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.logoRed,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          'Осталось ${product.stock} шт.',
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
