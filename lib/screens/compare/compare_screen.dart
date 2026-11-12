import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/cart_actions.dart';
import '../../core/utils/formatters.dart';
import '../../models/product.dart';
import '../../models/user_sizes.dart';
import '../../services/size_advisor.dart';
import '../../state/compare_state.dart';
import '../../state/profile_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_image.dart';

/// Сравнение товаров: таблица характеристик, лучшие значения
/// подсвечены, внизу — короткий вывод.
class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});

  static const double _labelWidth = 92;
  static const double _columnWidth = 136;
  static const SizeAdvisor _sizeAdvisor = SizeAdvisor();

  @override
  Widget build(BuildContext context) {
    final CompareState state = context.watch<CompareState>();
    final List<Product> items = state.items;
    final UserSizes? sizes = context.watch<ProfileState>().sizes;

    if (items.isEmpty) {
      return AppScaffold(
        title: 'Сравнение',
        navTab: MainTab.catalog,
        body: EmptyState(
          icon: Icons.compare_arrows,
          title: 'Нечего сравнивать',
          message: 'Добавьте в сравнение до ${CompareState.maxItems} товаров '
              'кнопкой со стрелками в карточке товара',
          actionText: 'Перейти в каталог',
          onAction: () => Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.main,
            (route) => false,
            arguments: MainTab.catalog,
          ),
        ),
      );
    }

    final Product cheapest = items.reduce((a, b) => a.price <= b.price ? a : b);
    final Product bestRated =
        items.reduce((a, b) => (a.rating ?? 0) >= (b.rating ?? 0) ? a : b);
    final bool canHighlight = items.length > 1;

    final List<_Row> rows = [
      _Row('Цена', [
        for (final Product p in items)
          _Cell(Formatters.price(p.price), best: canHighlight && p == cheapest),
      ]),
      _Row('Рейтинг', [
        for (final Product p in items)
          _Cell(
            p.rating == null
                ? '—'
                : '${p.rating!.toStringAsFixed(1).replaceAll('.', ',')} из 5',
            best: canHighlight && p == bestRated && p.rating != null,
          ),
      ]),
      _Row('Бренд', [for (final Product p in items) _Cell(p.brand ?? '—')]),
      _Row('Материал', [for (final Product p in items) _Cell(p.material ?? '—')]),
      _Row('Категория', [for (final Product p in items) _Cell(p.categoryName ?? '—')]),
      _Row('Вид спорта', [for (final Product p in items) _Cell(p.sportName ?? '—')]),
      _Row('Размеры', [
        for (final Product p in items)
          _Cell(p.requiresSize ? p.availableSizes.join(', ') : 'Без размера'),
      ]),
      if (sizes != null)
        _Row('Ваш размер', [
          for (final Product p in items)
            _Cell(_sizeAdvisor.advise(p, sizes)?.size ?? '—'),
        ]),
      _Row('Наличие', [
        for (final Product p in items)
          _Cell(
            p.isAvailable ? '${p.stock} шт.' : 'Нет',
            warn: !p.isAvailable,
          ),
      ]),
    ];

    return AppScaffold(
      title: 'Сравнение',
      navTab: MainTab.catalog,
      titleTrailing: TextButton(
        onPressed: context.read<CompareState>().clear,
        child: const Text('Очистить'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.screenPadding),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
            child: AppCard(
              padding: const EdgeInsets.all(AppSizes.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: _labelWidth),
                      for (final Product product in items)
                        _ProductHeader(product: product, width: _columnWidth),
                    ],
                  ),
                  for (int i = 0; i < rows.length; i++)
                    Container(
                      color: i.isEven ? AppColors.imagePlaceholder : null,
                      padding: const EdgeInsets.symmetric(vertical: AppSizes.s),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: _labelWidth,
                            child: Padding(
                              padding: const EdgeInsets.only(left: AppSizes.s),
                              child: Text(rows[i].label, style: AppTextStyles.bodySecondary),
                            ),
                          ),
                          for (final _Cell cell in rows[i].cells)
                            SizedBox(
                              width: _columnWidth,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: AppSizes.xs),
                                child: Text(
                                  cell.text,
                                  style: AppTextStyles.bodySecondary.copyWith(
                                    color: cell.warn
                                        ? AppColors.error
                                        : cell.best
                                            ? AppColors.success
                                            : AppColors.textPrimary,
                                    fontWeight:
                                        cell.best ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (canHighlight)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                AppSizes.l,
                AppSizes.screenPadding,
                0,
              ),
              child: _Verdict(cheapest: cheapest, bestRated: bestRated),
            ),
        ],
      ),
    );
  }
}

class _Row {
  const _Row(this.label, this.cells);

  final String label;
  final List<_Cell> cells;
}

class _Cell {
  const _Cell(this.text, {this.best = false, this.warn = false});

  final String text;
  final bool best;
  final bool warn;
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({required this.product, required this.width});

  final Product product;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSizes.xs, 0, AppSizes.xs, AppSizes.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                InkWell(
                  onTap: () => Navigator.of(context)
                      .pushNamed(AppRoutes.product, arguments: product.id),
                  child: ProductImage(
                    imageUrl: product.imageUrl,
                    width: double.infinity,
                    height: 96,
                    borderRadius: AppSizes.radiusS,
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    tooltip: 'Убрать из сравнения',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => context.read<CompareState>().remove(product),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.xs),
            SizedBox(
              height: 38,
              child: Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySecondary.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            SizedBox(
              height: 34,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  textStyle: AppTextStyles.caption
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                onPressed: () => CartActions.addToCart(context, product),
                child: const Text('В корзину'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Короткий вывод под таблицей: что дешевле, что лучше оценено.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.cheapest, required this.bestRated});

  final Product cheapest;
  final Product bestRated;

  @override
  Widget build(BuildContext context) {
    final String text = cheapest == bestRated
        ? '«${cheapest.name}» выигрывает и по цене, и по оценкам покупателей.'
        : 'Дешевле всего «${cheapest.name}» '
            '(${Formatters.price(cheapest.price)}). Выше всех оценён '
            '«${bestRated.name}» — разница в цене '
            '${Formatters.price(bestRated.price - cheapest.price)}.';
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.accent),
          const SizedBox(width: AppSizes.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Вывод', style: AppTextStyles.sectionTitle),
                const SizedBox(height: AppSizes.xs),
                Text(text, style: AppTextStyles.body.copyWith(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
