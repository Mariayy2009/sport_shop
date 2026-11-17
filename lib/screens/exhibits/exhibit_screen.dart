import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/cart_actions.dart';
import '../../data/repositories/exhibit_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../models/exhibit.dart';
import '../../models/product.dart';
import '../../models/product_filter.dart';
import '../../models/try_on.dart';
import '../../state/auth_state.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/exhibit_card.dart';
import '../../widgets/product_card.dart';
import '../../widgets/product_image.dart';
import '../../widgets/section_header.dart';

/// Экспонат «Зала славы»: фото, история и переход к покупке —
/// похожие товары каталога, примерка похожей вещи, комплект
/// для этого вида спорта.
class ExhibitScreen extends StatefulWidget {
  const ExhibitScreen({super.key, required this.exhibitId});

  final int exhibitId;

  @override
  State<ExhibitScreen> createState() => _ExhibitScreenState();
}

class _ExhibitData {
  const _ExhibitData(this.exhibit, this.similar);

  final Exhibit? exhibit;

  /// Товары того же вида спорта: сначала то, что можно примерить.
  final List<Product> similar;
}

class _ExhibitScreenState extends State<ExhibitScreen> {
  static const int _maxSimilar = 8;
  late Future<_ExhibitData> _future = _load();

  Future<_ExhibitData> _load() async {
    final ProductRepository products = context.read<ProductRepository>();
    final Exhibit? exhibit =
        await context.read<ExhibitRepository>().getById(widget.exhibitId);
    if (exhibit?.sportId == null) return _ExhibitData(exhibit, const []);
    final List<Product> similar = await products.getProducts(
      ProductFilter(sportId: exhibit!.sportId, onlyAvailable: true),
    );
    int rank(Product product) => TryOnSupport.of(product).any ? 0 : 1;
    similar.sort((a, b) {
      final int byWearable = rank(a).compareTo(rank(b));
      return byWearable != 0
          ? byWearable
          : (b.rating ?? 0).compareTo(a.rating ?? 0);
    });
    return _ExhibitData(exhibit, similar.take(_maxSimilar).toList());
  }

  Future<void> _edit(Exhibit exhibit) async {
    final NavigatorState navigator = Navigator.of(context);
    final Object? changed =
        await navigator.pushNamed(AppRoutes.adminExhibit, arguments: exhibit);
    if (changed != true || !mounted) return;
    // После удаления экспоната возвращаемся к списку.
    final Exhibit? still =
        await context.read<ExhibitRepository>().getById(widget.exhibitId);
    if (!mounted) return;
    if (still == null) {
      navigator.pop();
    } else {
      setState(() => _future = _load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = context.watch<AuthState>().isAdmin;
    return FutureBuilder<_ExhibitData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppScaffold(
            title: 'Экспонат',
            navTab: MainTab.home,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final Exhibit? exhibit = snapshot.data?.exhibit;
        if (exhibit == null) {
          return const AppScaffold(
            title: 'Экспонат',
            navTab: MainTab.home,
            body: EmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'Экспонат не найден',
            ),
          );
        }
        final List<Product> similar = snapshot.data!.similar;
        Product? wearable;
        for (final Product product in similar) {
          if (TryOnSupport.of(product).any) {
            wearable = product;
            break;
          }
        }

        return AppScaffold(
          title: 'Экспонат',
          navTab: MainTab.home,
          titleTrailing: isAdmin
              ? IconButton(
                  tooltip: 'Редактировать экспонат',
                  onPressed: () => _edit(exhibit),
                  icon: const Icon(Icons.edit_outlined),
                )
              : null,
          bottomAction: wearable == null
              ? null
              : CustomButton(
                  text: 'Примерить похожее',
                  onPressed: () => Navigator.of(context)
                      .pushNamed(AppRoutes.tryOn, arguments: wearable!.id),
                ),
          body: ListView(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            children: [
              AspectRatio(
                aspectRatio: 0.85,
                child: ProductImage(
                  imageUrl: exhibit.imageUrl,
                  width: double.infinity,
                  borderRadius: AppSizes.radiusL,
                  placeholderIcon: Icons.emoji_events_outlined,
                ),
              ),
              const SizedBox(height: AppSizes.l),
              Row(
                children: [
                  ExhibitSourceBadge(source: exhibit.source),
                  const SizedBox(width: AppSizes.s),
                  Expanded(
                    child: Text(
                      [exhibit.sportTitle, exhibit.year]
                          .whereType<String>()
                          .join(' · '),
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.s),
              Text(exhibit.title, style: AppTextStyles.screenTitle),
              const SizedBox(height: AppSizes.xxs),
              Text(
                exhibit.athlete,
                style: AppTextStyles.sectionTitle
                    .copyWith(color: AppColors.accentDark),
              ),
              if (exhibit.story != null) ...[
                const SizedBox(height: AppSizes.m),
                Text(
                  exhibit.story!,
                  style: AppTextStyles.body.copyWith(height: 1.5),
                ),
              ],
              const SizedBox(height: AppSizes.s),
              Text(exhibit.source.fullLabel, style: AppTextStyles.caption),
              if (similar.isEmpty) ...[
                const SizedBox(height: AppSizes.l),
                const Text(
                  'Экипировки для этого вида спорта в каталоге пока нет — '
                  'загляни в другие экспонаты.',
                  style: AppTextStyles.bodySecondary,
                ),
              ],
              if (similar.isNotEmpty) ...[
                const SizedBox(height: AppSizes.l),
                SectionHeader(
                  title: 'Экипировка в том же духе',
                  actionText: 'Комплект',
                  onAction: () => Navigator.of(context)
                      .pushNamed(AppRoutes.kits, arguments: exhibit.sportId),
                ),
                const SizedBox(height: AppSizes.s),
                SizedBox(
                  height: ProductCard.height,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: similar.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: AppSizes.m),
                    itemBuilder: (context, index) {
                      final Product product = similar[index];
                      return ProductCard(
                        product: product,
                        caption: product.brand,
                        onTap: () => Navigator.of(context)
                            .pushNamed(AppRoutes.product, arguments: product.id),
                        onAdd: () => CartActions.addToCart(context, product),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
