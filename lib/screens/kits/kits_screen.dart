import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/sport_visuals.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/product_actions.dart';
import '../../models/enums.dart';
import '../../models/sport.dart';
import '../../models/sport_kit.dart';
import '../../models/user_sizes.dart';
import '../../services/kit_service.dart';
import '../../state/cart_state.dart';
import '../../state/product_state.dart';
import '../../state/profile_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_image.dart';
import '../../widgets/size_picker_sheet.dart';

/// Персональные комплекты: готовый набор экипировки для вида спорта
/// и уровня. Можно купить целиком или снять галочки с лишнего;
/// размеры подставляются из профиля.
class KitsScreen extends StatefulWidget {
  const KitsScreen({super.key, this.initialSportId});

  final int? initialSportId;

  @override
  State<KitsScreen> createState() => _KitsScreenState();
}

class _KitsScreenState extends State<KitsScreen> {
  int? _sportId;
  SportLevel? _level;
  Future<SportKit>? _future;

  /// id товаров, с которых пользователь снял галочку.
  final Set<int> _excluded = {};

  /// Размеры, выбранные вручную вместо подобранных.
  final Map<int, String> _sizeOverrides = {};
  bool _isAdding = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future != null) return;
    final UserSizes? sizes = context.read<ProfileState>().sizes;
    final List<Sport> sports = context.read<ProductState>().sports;
    _sportId = widget.initialSportId ?? sizes?.sportId ?? sports.firstOrNull?.id;
    _level = sizes?.experienceYears == null ? SportLevel.beginner : sizes!.level;
    _reload();
  }

  void _reload() {
    final Sport? sport = _sport;
    if (sport == null) return;
    _excluded.clear();
    _sizeOverrides.clear();
    _future = context.read<KitService>().buildKit(
          sport: sport,
          level: _level!,
          sizes: context.read<ProfileState>().sizes,
        );
  }

  Sport? get _sport {
    for (final Sport sport in context.read<ProductState>().sports) {
      if (sport.id == _sportId) return sport;
    }
    return null;
  }

  String? _sizeOf(KitItem item) => _sizeOverrides[item.product.id] ?? item.size;

  List<KitItem> _selected(SportKit kit) => kit.items
      .where((item) =>
          !_excluded.contains(item.product.id) && item.product.isAvailable)
      .toList();

  Future<void> _changeSize(KitItem item) async {
    final String? size = await SizePickerSheet.show(
      context,
      item.product,
      initialSize: _sizeOf(item),
    );
    if (size != null && mounted) {
      setState(() => _sizeOverrides[item.product.id!] = size);
    }
  }

  Future<void> _addSelected(SportKit kit) async {
    setState(() => _isAdding = true);
    await ProductActions.addAllToCart(context, [
      for (final KitItem item in _selected(kit))
        (product: item.product, size: _sizeOf(item)),
    ]);
    if (mounted) setState(() => _isAdding = false);
  }

  @override
  Widget build(BuildContext context) {
    final List<Sport> sports = context.watch<ProductState>().sports;
    if (sports.isEmpty || _future == null) {
      return const AppScaffold(
        title: 'Комплекты',
        navTab: MainTab.home,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return FutureBuilder<SportKit>(
      future: _future,
      builder: (context, snapshot) {
        final SportKit? kit = snapshot.data;
        final List<KitItem> selected = kit == null ? const [] : _selected(kit);
        return AppScaffold(
          title: 'Комплекты',
          navTab: MainTab.home,
          bottomAction: kit == null || selected.isEmpty
              ? null
              : CustomButton(
                  text: 'В корзину: ${Formatters.itemsCount(selected.length)} — '
                      '${Formatters.price(SportKit.priceOf(selected))}',
                  isLoading: _isAdding,
                  onPressed: () => _addSelected(kit),
                ),
          body: Column(
            children: [
              _SportPicker(
                sports: sports,
                selectedId: _sportId,
                onSelected: (id) => setState(() {
                  _sportId = id;
                  _reload();
                }),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
                child: SegmentedButton<SportLevel>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    selectedBackgroundColor: AppColors.black,
                    selectedForegroundColor: AppColors.white,
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    textStyle: AppTextStyles.bodySecondary
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  segments: [
                    for (final SportLevel level in SportLevel.values)
                      ButtonSegment(value: level, label: Text(level.label)),
                  ],
                  selected: {_level!},
                  onSelectionChanged: (value) => setState(() {
                    _level = value.first;
                    _reload();
                  }),
                ),
              ),
              Expanded(
                child: snapshot.connectionState != ConnectionState.done
                    ? const Center(child: CircularProgressIndicator())
                    : kit == null || kit.items.isEmpty
                        ? const EmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'Комплект пока не собран',
                            message: 'Для этого вида спорта и уровня '
                                'готового набора ещё нет',
                          )
                        : _buildKit(kit),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKit(SportKit kit) {
    final Set<int> cartIds = context.watch<CartState>().productIds;
    final bool hasProfile = context.watch<ProfileState>().sizes != null;
    return ListView(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        Text(
          'Комплект для ${SportVisuals.of(kit.sport.name).genitive}',
          style: AppTextStyles.sectionTitle,
        ),
        const SizedBox(height: AppSizes.xxs),
        Text(
          'Уровень «${kit.level.label.toLowerCase()}» · основа '
          '${Formatters.price(kit.basePrice)}'
          '${hasProfile ? ' · размеры из профиля' : ''}',
          style: AppTextStyles.bodySecondary,
        ),
        const SizedBox(height: AppSizes.m),
        for (final KitItem item in kit.mandatory) _itemTile(item, cartIds),
        if (kit.extras.isNotEmpty) ...[
          const SizedBox(height: AppSizes.s),
          const Text('Дополнения', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSizes.s),
          for (final KitItem item in kit.extras) _itemTile(item, cartIds),
        ],
      ],
    );
  }

  Widget _itemTile(KitItem item, Set<int> cartIds) {
    final int id = item.product.id!;
    final bool available = item.product.isAvailable;
    final bool checked = available && !_excluded.contains(id);
    final String? size = _sizeOf(item);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.s),
      child: AppCard(
        padding: const EdgeInsets.all(AppSizes.s),
        onTap: () =>
            Navigator.of(context).pushNamed(AppRoutes.product, arguments: id),
        child: Row(
          children: [
            Checkbox(
              value: checked,
              activeColor: AppColors.black,
              visualDensity: VisualDensity.compact,
              onChanged: available
                  ? (value) => setState(() {
                        value == true ? _excluded.remove(id) : _excluded.add(id);
                      })
                  : null,
            ),
            ProductImage(
              imageUrl: item.product.imageUrl,
              width: 56,
              height: 56,
              borderRadius: AppSizes.radiusS,
            ),
            const SizedBox(width: AppSizes.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    !available
                        ? 'Нет в наличии'
                        : cartIds.contains(id)
                            ? 'Уже в корзине'
                            : item.product.categoryName ?? '',
                    style: AppTextStyles.caption.copyWith(
                      color: available ? AppColors.textSecondary : AppColors.error,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xxs),
                  Text(Formatters.price(item.product.price), style: AppTextStyles.price),
                ],
              ),
            ),
            if (item.product.requiresSize)
              ActionChip(
                label: Text(size ?? 'Размер'),
                labelStyle: AppTextStyles.bodySecondary.copyWith(
                  color: size == null ? AppColors.error : AppColors.accentDark,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: AppColors.accentSoft,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
                tooltip: 'Изменить размер',
                onPressed: () => _changeSize(item),
              ),
          ],
        ),
      ),
    );
  }
}

class _SportPicker extends StatelessWidget {
  const _SportPicker({
    required this.sports,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Sport> sports;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.screenPadding,
          vertical: AppSizes.m,
        ),
        itemCount: sports.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppSizes.s),
        itemBuilder: (context, index) {
          final Sport sport = sports[index];
          final bool isSelected = sport.id == selectedId;
          return ChoiceChip(
            selected: isSelected,
            showCheckmark: false,
            avatar: Icon(
              SportVisuals.of(sport.name).icon,
              size: 16,
              color: isSelected ? AppColors.white : AppColors.textPrimary,
            ),
            label: Text(sport.name),
            labelStyle: AppTextStyles.bodySecondary.copyWith(
              color: isSelected ? AppColors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: AppColors.surface,
            selectedColor: AppColors.black,
            side: BorderSide(
              color: isSelected ? AppColors.black : AppColors.border,
            ),
            shape: const StadiumBorder(),
            onSelected: (_) => onSelected(sport.id!),
          );
        },
      ),
    );
  }
}
