import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/cart_actions.dart';
import '../../data/repositories/product_repository.dart';
import '../../models/product.dart';
import '../../models/product_filter.dart';
import '../../models/sport.dart';
import '../../models/user.dart';
import '../../models/user_sizes.dart';
import '../../state/auth_state.dart';
import '../../state/compare_state.dart';
import '../../state/product_state.dart';
import '../../state/profile_state.dart';
import '../../widgets/product_card.dart';
import '../../widgets/search_field.dart';
import '../../widgets/section_header.dart';
import '../../widgets/sport_tile.dart';

/// Главная: приветствие, поиск, вход к ИИ-помощнику, быстрые действия
/// (комплекты, примерочная, сравнение), товары для вида спорта
/// пользователя и сетка видов спорта.
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
    final User? user = context.watch<AuthState>().currentUser;
    final UserSizes? sizes = context.watch<ProfileState>().sizes;
    final int compareCount = context.watch<CompareState>().count;

    return RefreshIndicator(
      onRefresh: productState.init,
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        children: [
          Text(
            user == null ? 'Добро пожаловать!' : 'Привет, ${user.greetingName}!',
            style: AppTextStyles.screenTitle,
          ),
          const SizedBox(height: AppSizes.xxs),
          const Text(
            'Подберём экипировку под твой спорт',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: AppSizes.l),
          SearchField(
            onSearch: (query) {
              if (query.isEmpty) return;
              context.read<ProductState>().applyFilter(ProductFilter(query: query));
              onOpenCatalog();
            },
          ),
          const SizedBox(height: AppSizes.l),
          _AiBanner(onTap: onOpenAi),
          const SizedBox(height: AppSizes.m),
          Row(
            children: [
              _QuickAction(
                icon: Icons.inventory_2_outlined,
                label: 'Комплекты',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.kits),
              ),
              const SizedBox(width: AppSizes.s),
              _QuickAction(
                icon: Icons.checkroom,
                label: 'Примерка',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.fittingRoom),
              ),
              const SizedBox(width: AppSizes.s),
              _QuickAction(
                icon: Icons.compare_arrows,
                label: 'Сравнение',
                badge: compareCount,
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.compare),
              ),
            ],
          ),
          _ForYouSection(
            sportId: sizes?.sportId,
            sportName: sizes?.sportName,
          ),
          const SizedBox(height: AppSizes.l),
          SectionHeader(
            title: 'Виды спорта',
            actionText: 'Все товары',
            onAction: () {
              context.read<ProductState>().showAll();
              onOpenCatalog();
            },
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
              mainAxisSpacing: AppSizes.m,
              crossAxisSpacing: AppSizes.m,
              childAspectRatio: 1.25,
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

/// Баннер-вход к ИИ-помощнику.
class _AiBanner extends StatelessWidget {
  const _AiBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(AppSizes.radiusL);
    return Ink(
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: radius,
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.l),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: AppColors.white),
              ),
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
                      'ИИ-помощник соберёт комплект, подберёт размер '
                      'и уложится в бюджет',
                      style: AppTextStyles.bodySecondary.copyWith(
                        color: AppColors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: AppColors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(AppSizes.radiusM);
    return Expanded(
      child: Material(
        color: AppColors.surface,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.m),
            child: Column(
              children: [
                Badge(
                  isLabelVisible: badge > 0,
                  backgroundColor: AppColors.accent,
                  label: Text('$badge'),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.accentSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: AppColors.accentDark, size: 20),
                  ),
                ),
                const SizedBox(height: AppSizes.s),
                Text(
                  label,
                  style: AppTextStyles.bodySecondary.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Лента товаров: для вида спорта из профиля, а без него — с лучшим рейтингом.
class _ForYouSection extends StatefulWidget {
  const _ForYouSection({required this.sportId, required this.sportName});

  final int? sportId;
  final String? sportName;

  @override
  State<_ForYouSection> createState() => _ForYouSectionState();
}

class _ForYouSectionState extends State<_ForYouSection> {
  static const int _maxItems = 8;
  late Future<List<Product>> _future = _load();

  @override
  void didUpdateWidget(_ForYouSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sportId != widget.sportId) _future = _load();
  }

  Future<List<Product>> _load() async {
    final List<Product> products = await context
        .read<ProductRepository>()
        .getProducts(ProductFilter(sportId: widget.sportId, onlyAvailable: true));
    products.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return products.take(_maxItems).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: _future,
      builder: (context, snapshot) {
        final List<Product> items = snapshot.data ?? const [];
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSizes.l),
            SectionHeader(
              title: widget.sportName == null
                  ? 'Выбор покупателей'
                  : 'Для тебя · ${widget.sportName}',
              actionText: widget.sportId == null ? null : 'Комплект',
              onAction: () => Navigator.of(context)
                  .pushNamed(AppRoutes.kits, arguments: widget.sportId),
            ),
            const SizedBox(height: AppSizes.s),
            SizedBox(
              height: ProductCard.height,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: AppSizes.m),
                itemBuilder: (context, index) {
                  final Product product = items[index];
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
        );
      },
    );
  }
}
