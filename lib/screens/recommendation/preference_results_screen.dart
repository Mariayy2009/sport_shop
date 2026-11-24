import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/cart_actions.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/preferences_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../models/product.dart';
import '../../models/shopping_preferences.dart';
import '../../models/user_sizes.dart';
import '../../services/preferences/preference_matcher.dart';
import '../../services/preferences/style_catalog.dart';
import '../../state/auth_state.dart';
import '../../state/profile_state.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_image.dart';

/// «Подбор по анкете»: товары под позицию, любимые цвета и материал —
/// как фильтр каталога, у каждого товара написано, почему он здесь.
class PreferenceResultsScreen extends StatefulWidget {
  const PreferenceResultsScreen({super.key});

  @override
  State<PreferenceResultsScreen> createState() =>
      _PreferenceResultsScreenState();
}

class _Data {
  const _Data(this.preferences, this.matches);

  final ShoppingPreferences preferences;
  final List<PreferenceMatch> matches;
}

class _PreferenceResultsScreenState extends State<PreferenceResultsScreen> {
  static const PreferenceMatcher _matcher = PreferenceMatcher();
  late Future<_Data> _future = _load();

  // Фильтры: показывать только то, что совпало по этому признаку.
  bool _onlyPosition = false;
  bool _onlyColor = false;
  bool _onlyMaterial = false;

  Future<_Data> _load() async {
    final int? userId = context.read<AuthState>().currentUser?.id;
    final UserSizes? sizes = context.read<ProfileState>().sizes;
    final ProductRepository products = context.read<ProductRepository>();
    final ShoppingPreferences preferences = userId == null
        ? const ShoppingPreferences()
        : await context.read<PreferencesRepository>().read(userId);
    final List<Product> catalog = await products.getProducts();
    final Map<int, String> colors = await PreferenceMatcher.colorsOf(catalog);
    return _Data(
      preferences,
      _matcher.rank(
        catalog,
        preferences,
        sportId: sizes?.sportId,
        sportName: sizes?.sportName,
        colors: colors,
      ),
    );
  }

  Future<void> _editForm() async {
    await Navigator.of(context).pushNamed(AppRoutes.preferences);
    if (mounted) setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Подбор по анкете',
      navTab: MainTab.home,
      titleTrailing: IconButton(
        tooltip: 'Изменить анкету',
        onPressed: _editForm,
        icon: const Icon(Icons.tune),
      ),
      body: FutureBuilder<_Data>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final _Data? data = snapshot.data;
          if (data == null || data.preferences.isEmpty) {
            return EmptyState(
              icon: Icons.tune,
              title: 'Заполни анкету',
              message: 'Любимые цвета, позиция в игре и материал — '
                  'и мы подберём вещи под тебя',
              actionText: 'Заполнить анкету',
              onAction: _editForm,
            );
          }
          final ShoppingPreferences p = data.preferences;
          final List<PreferenceMatch> shown = data.matches
              .where((m) =>
                  (!_onlyPosition || m.forPosition) &&
                  (!_onlyColor || m.inColor) &&
                  (!_onlyMaterial || m.inMaterial))
              .toList();
          return ListView(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            children: [
              Text(_summary(p, context.read<ProfileState>().sizes?.sportName),
                  style: AppTextStyles.bodySecondary),
              const SizedBox(height: AppSizes.m),
              Wrap(
                spacing: AppSizes.s,
                runSpacing: AppSizes.s,
                children: [
                  if (p.position != null)
                    FilterChip(
                      label: const Text('Для моей позиции'),
                      selected: _onlyPosition,
                      onSelected: (value) => setState(() => _onlyPosition = value),
                    ),
                  if (p.colors.isNotEmpty)
                    FilterChip(
                      label: const Text('Мои цвета'),
                      selected: _onlyColor,
                      onSelected: (value) => setState(() => _onlyColor = value),
                    ),
                  if (p.materials.isNotEmpty)
                    FilterChip(
                      label: const Text('Мой материал'),
                      selected: _onlyMaterial,
                      onSelected: (value) => setState(() => _onlyMaterial = value),
                    ),
                ],
              ),
              const SizedBox(height: AppSizes.m),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSizes.xl),
                  child: Text(
                    'С такими фильтрами ничего не нашлось — сними один из них',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySecondary,
                  ),
                ),
              for (final PreferenceMatch match in shown)
                _MatchCard(match: match),
            ],
          );
        },
      ),
    );
  }

  static String _summary(ShoppingPreferences p, String? sportName) {
    final List<String> parts = [
      if (StyleCatalog.position(sportName, p.position) case final SportPosition position)
        '${sportName!.toLowerCase()}, ${position.title.toLowerCase()}',
      if (p.colors.isNotEmpty)
        'цвета: ${p.colors.map((key) => StyleCatalog.colorByKey(key)?.name.toLowerCase()).whereType<String>().join(', ')}',
      if (p.materials.isNotEmpty)
        'материал: ${p.materials.map((key) => StyleCatalog.materialByKey(key)?.name.toLowerCase()).whereType<String>().join(', ')}',
    ];
    return 'По анкете: ${parts.join(' · ')}';
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});

  final PreferenceMatch match;

  @override
  Widget build(BuildContext context) {
    final Product product = match.product;
    final BorderRadius radius = BorderRadius.circular(AppSizes.radiusM);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.m),
      child: Material(
        color: AppColors.surface,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.product, arguments: product.id),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.m),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductImage(imageUrl: product.imageUrl, width: 84, height: 84),
                const SizedBox(width: AppSizes.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(Formatters.price(product.price), style: AppTextStyles.price),
                      const SizedBox(height: AppSizes.xs),
                      for (final String reason in match.reasons)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSizes.xxs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(Icons.check, size: 14, color: AppColors.success),
                              ),
                              const SizedBox(width: AppSizes.xxs),
                              Expanded(
                                child: Text(reason, style: AppTextStyles.caption),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'В корзину',
                  onPressed: () => CartActions.addToCart(context, product),
                  icon: const Icon(Icons.add_shopping_cart),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
