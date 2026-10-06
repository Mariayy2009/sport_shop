import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/cart_actions.dart';
import '../../core/utils/formatters.dart';
import '../../models/product.dart';
import '../../models/product_filter.dart';
import '../../state/product_state.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_list_item.dart';
import '../../widgets/screen_title_bar.dart';
import '../../widgets/search_field.dart';

/// Каталог товаров (фрейм Figma «каталог»): поиск, фильтры, сортировка,
/// активные фильтры чипами, список товаров.
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ProductState state = context.watch<ProductState>();
    final ProductFilter filter = state.filter;

    return Column(
      children: [
        const ScreenTitleBar(title: 'Каталог товаров', showBack: false),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            AppSizes.m,
            AppSizes.screenPadding,
            0,
          ),
          child: Column(
            children: [
              SearchField(
                initialValue: filter.query,
                searchOnType: true,
                onSearch: context.read<ProductState>().search,
              ),
              const SizedBox(height: AppSizes.s),
              Row(
                children: [
                  _FilterButton(
                    activeCount: filter.activeCount,
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.filter),
                  ),
                  const Spacer(),
                  _SortButton(state: state),
                ],
              ),
              if (filter.hasActiveFilters) _ActiveFilters(state: state),
            ],
          ),
        ),
        Expanded(child: _buildList(context, state)),
      ],
    );
  }

  Widget _buildList(BuildContext context, ProductState state) {
    if (state.isLoading && state.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return EmptyState(
        icon: Icons.cloud_off,
        title: 'Ошибка загрузки',
        message: state.error,
        actionText: 'Повторить',
        onAction: state.loadProducts,
      );
    }
    if (state.products.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'Ничего не найдено',
        message: 'Попробуйте изменить запрос или сбросить фильтры',
        actionText: 'Сбросить фильтры',
        onAction: () => context.read<ProductState>().showAll(),
      );
    }

    final List<Product> products = state.products;
    return RefreshIndicator(
      onRefresh: state.loadProducts,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        itemCount: products.length + 1,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSizes.s),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Text(
              'Найдено: ${Formatters.itemsCount(products.length)}',
              style: AppTextStyles.caption,
            );
          }
          final Product product = products[index - 1];
          return ProductListItem(
            product: product,
            onTap: () => Navigator.of(context)
                .pushNamed(AppRoutes.product, arguments: product.id),
            onAddToCart: () => CartActions.addToCart(context, product),
          );
        },
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.activeCount, required this.onTap});

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isActive = activeCount > 0;
    return Material(
      color: isActive ? AppColors.black : AppColors.surface,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.black)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.m,
            vertical: AppSizes.xs + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune,
                size: 16,
                color: isActive ? AppColors.white : AppColors.black,
              ),
              const SizedBox(width: AppSizes.xs),
              Text(
                isActive ? 'Фильтры ($activeCount)' : 'Фильтры',
                style: AppTextStyles.bodySecondary.copyWith(
                  color: isActive ? AppColors.white : AppColors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.state});

  final ProductState state;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ProductSort>(
      tooltip: 'Сортировка',
      initialValue: state.sort,
      color: AppColors.surface,
      onSelected: context.read<ProductState>().setSort,
      itemBuilder: (context) => [
        for (final ProductSort sort in ProductSort.values)
          PopupMenuItem<ProductSort>(value: sort, child: Text(sort.label)),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(state.sort.label, style: AppTextStyles.bodySecondary),
          const Icon(Icons.keyboard_arrow_down, size: 18),
        ],
      ),
    );
  }
}

/// Чипы активных фильтров с крестиком — убрать один фильтр.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.state});

  final ProductState state;

  @override
  Widget build(BuildContext context) {
    final ProductFilter filter = state.filter;
    final ProductState actions = context.read<ProductState>();
    final List<(String, ProductFilter)> chips = [
      if (filter.sportId != null)
        (state.sportName(filter.sportId) ?? 'Спорт',
            filter.copyWith(clearSport: true)),
      if (filter.categoryId != null)
        (state.categoryName(filter.categoryId) ?? 'Категория',
            filter.copyWith(clearCategory: true)),
      if (filter.size != null)
        ('Размер ${filter.size}', filter.copyWith(clearSize: true)),
      if (filter.minPrice != null || filter.maxPrice != null)
        (_priceLabel(filter), filter.copyWith(clearPrice: true)),
      if (filter.onlyAvailable)
        ('В наличии', filter.copyWith(onlyAvailable: false)),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.s),
      child: SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final (String label, ProductFilter without) in chips)
              Padding(
                padding: const EdgeInsets.only(right: AppSizes.xs),
                child: InputChip(
                  label: Text(label, style: AppTextStyles.caption),
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                  shape: const StadiumBorder(),
                  visualDensity: VisualDensity.compact,
                  onDeleted: () => actions.applyFilter(without),
                  deleteIcon: const Icon(Icons.close, size: 14),
                ),
              ),
            TextButton(
              onPressed: actions.resetFilters,
              child: const Text('Сбросить'),
            ),
          ],
        ),
      ),
    );
  }

  static String _priceLabel(ProductFilter filter) {
    final double? min = filter.minPrice;
    final double? max = filter.maxPrice;
    if (min != null && max != null) {
      return '${Formatters.price(min)} – ${Formatters.price(max)}';
    }
    if (min != null) return 'от ${Formatters.price(min)}';
    return 'до ${Formatters.price(max!)}';
  }
}
