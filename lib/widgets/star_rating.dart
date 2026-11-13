import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

/// Пять звёзд: показ оценки или её выбор, если задан [onChanged].
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    this.onChanged,
    this.size = 16,
  });

  final int rating;
  final ValueChanged<int>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Оценка $rating из 5',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int value = 1; value <= 5; value++)
            onChanged == null
                ? _star(value)
                : IconButton(
                    tooltip: '$value',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () => onChanged!(value),
                    icon: _star(value),
                  ),
        ],
      ),
    );
  }

  Widget _star(int value) => Icon(
        value <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
        size: size,
        color: value <= rating ? AppColors.star : AppColors.textHint,
      );
}
