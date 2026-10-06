import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/product_filter.dart';
import '../../models/sport.dart';
import '../../state/product_state.dart';
import '../../widgets/search_field.dart';
import '../../widgets/sport_tile.dart';

/// Главная (фрейм Figma «главная»): поиск, баннер AI-подбора,
/// сетка видов спорта. Плитка открывает каталог этого вида спорта.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenCatalog,
    required this.onOpenAi,
  });

  final VoidCallback onOpenCatalog;
  final VoidCallback onOpenAi;

  @override
  Widget build(BuildContext context) {
    final ProductState productState = context.watch<ProductState>();
    final List<Sport> sports = productState.sports;

    return RefreshIndicator(
      onRefresh: productState.init,
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        children: [
          SearchField(
            onSearch: (query) {
              if (query.isEmpty) return;
              context.read<ProductState>().applyFilter(ProductFilter(query: query));
              onOpenCatalog();
            },
          ),
          const SizedBox(height: AppSizes.l),
          _AiBanner(onTap: onOpenAi),
          const SizedBox(height: AppSizes.l),
          Row(
            children: [
              const Expanded(
                child: Text('Виды спорта', style: AppTextStyles.sectionTitle),
              ),
              TextButton(
                onPressed: () {
                  context.read<ProductState>().showAll();
                  onOpenCatalog();
                },
                child: const Text('Все товары'),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.s),
          if (sports.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSizes.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSizes.s,
              crossAxisSpacing: AppSizes.s,
              children: [
                for (final Sport sport in sports)
                  SportTile(
                    sportName: sport.name,
                    onTap: () {
                      context.read<ProductState>().showSport(sport.id!);
                      onOpenCatalog();
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Чёрный баннер «Не знаешь, что купить?» — вход в AI-подбор.
class _AiBanner extends StatelessWidget {
  const _AiBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.black,
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.l),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.white, size: 32),
              const SizedBox(width: AppSizes.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Не знаешь, что купить?',
                      style: AppTextStyles.sectionTitle
                          .copyWith(color: AppColors.white),
                    ),
                    const SizedBox(height: AppSizes.xxs),
                    Text(
                      'AI подберёт экипировку под твой спорт, уровень и бюджет',
                      style: AppTextStyles.bodySecondary
                          .copyWith(color: AppColors.white),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.white),
            ],
          ),
        ),
      ),
    );
  }
}
