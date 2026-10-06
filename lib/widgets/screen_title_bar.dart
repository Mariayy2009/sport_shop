import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';

/// Белая строка заголовка под шапкой: «← Фильтры      Сбросить».
class ScreenTitleBar extends StatelessWidget {
  const ScreenTitleBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.trailing,
    this.onBack,
  });

  final String title;
  final bool showBack;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            if (showBack)
              IconButton(
                tooltip: 'Назад',
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
              )
            else
              const SizedBox(width: AppSizes.l),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.sectionTitle,
              ),
            ),
            if (trailing != null) trailing!,
            const SizedBox(width: AppSizes.s),
          ],
        ),
      ),
    );
  }
}
