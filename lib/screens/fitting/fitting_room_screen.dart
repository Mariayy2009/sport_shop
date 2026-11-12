import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/product_actions.dart';
import '../../data/repositories/product_repository.dart';
import '../../models/outfit.dart';
import '../../models/product.dart';
import '../../models/user_sizes.dart';
import '../../services/size_advisor.dart';
import '../../state/profile_state.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/avatar_painter.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/product_image.dart';

/// Виртуальная примерочная (бета).
///
/// Манекен строится по росту и весу из профиля. На него надеваются
/// товары каталога, цвет вещи можно менять, фигуру — поворачивать
/// жестом. Модель по фотографиям появится вместе с серверной частью:
/// реконструкция тела по фото выполняется на сервере.
class FittingRoomScreen extends StatefulWidget {
  const FittingRoomScreen({super.key, this.initialProductId});

  final int? initialProductId;

  @override
  State<FittingRoomScreen> createState() => _FittingRoomScreenState();
}

class _FittingRoomScreenState extends State<FittingRoomScreen> {
  static const int _defaultHeight = 170;
  static const int _defaultWeight = 65;
  static const double _maxAngle = 1.2; // ≈ 70°
  static const SizeAdvisor _sizeAdvisor = SizeAdvisor();

  late final Future<List<Product>> _future;
  Map<WearSlot, WornItem> _outfit = const {};
  WearSlot _slot = WearSlot.upper;
  double _angle = 0;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// Товары, которые можно примерить. Товар, с которого открыли
  /// примерочную, сразу надевается.
  Future<List<Product>> _load() async {
    final List<Product> all =
        await context.read<ProductRepository>().getProducts();
    final List<Product> wearable =
        all.where((product) => Outfit.kindOf(product) != null).toList();
    for (final Product product in wearable) {
      if (product.id == widget.initialProductId && mounted) {
        final WearKind kind = Outfit.kindOf(product)!;
        _slot = Outfit.slotOf(kind);
        _outfit = {
          _slot: WornItem(product: product, kind: kind, color: Outfit.defaultColor(kind)),
        };
      }
    }
    return wearable;
  }

  void _toggle(Product product) {
    final WearKind kind = Outfit.kindOf(product)!;
    final WearSlot slot = Outfit.slotOf(kind);
    final Map<WearSlot, WornItem> next = Map.of(_outfit);
    if (next[slot]?.product.id == product.id) {
      next.remove(slot);
    } else {
      next[slot] = WornItem(
        product: product,
        kind: kind,
        color: Outfit.defaultColor(kind),
      );
      // Форма, кимоно и купальник закрывают и низ.
      if (kind.coversLower) next.remove(WearSlot.lower);
      if (slot == WearSlot.lower && (next[WearSlot.upper]?.kind.coversLower ?? false)) {
        next.remove(WearSlot.upper);
      }
    }
    setState(() => _outfit = next);
  }

  void _recolor(Color color) {
    final WornItem? item = _outfit[_slot];
    if (item == null) return;
    setState(() => _outfit = {..._outfit, _slot: item.withColor(color)});
  }

  Future<void> _addToCart() async {
    final UserSizes? sizes = context.read<ProfileState>().sizes;
    setState(() => _isAdding = true);
    await ProductActions.addAllToCart(context, [
      for (final WornItem item in _outfit.values)
        (product: item.product, size: _sizeAdvisor.pickSize(item.product, sizes)),
    ]);
    if (mounted) setState(() => _isAdding = false);
  }

  void _showInfo() {
    AppMessages.showInfoDialog(
      context,
      title: 'Как работает примерка',
      message: 'Сейчас манекен строится по росту и весу из профиля — '
          'это бета-версия, она показывает сочетание вещей и цветов, '
          'но не точную посадку.\n\n'
          'Персональная 3D-модель по фотографиям появится вместе '
          'с серверной частью. Загрузка фото будет добровольной, '
          'снимки будут храниться в зашифрованном виде, и их можно '
          'будет удалить в любой момент.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final UserSizes? sizes = context.watch<ProfileState>().sizes;
    final double total =
        _outfit.values.fold(0, (sum, item) => sum + item.product.price);

    return AppScaffold(
      title: 'Примерочная',
      navTab: MainTab.home,
      titleTrailing: IconButton(
        tooltip: 'Как работает примерка',
        onPressed: _showInfo,
        icon: const Icon(Icons.info_outline),
      ),
      bottomAction: _outfit.isEmpty
          ? null
          : CustomButton(
              text: 'В корзину: ${Formatters.itemsCount(_outfit.length)} — '
                  '${Formatters.price(total)}',
              isLoading: _isAdding,
              onPressed: _addToCart,
            ),
      body: FutureBuilder<List<Product>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<Product> products = snapshot.data ?? const [];
          return Column(
            children: [
              Expanded(child: _buildStage(sizes)),
              _buildControls(products),
            ],
          );
        },
      ),
    );
  }

  /// Сцена с манекеном: поворот — горизонтальным жестом.
  Widget _buildStage(UserSizes? sizes) {
    final int height = sizes?.height ?? _defaultHeight;
    final int weight = sizes?.weight ?? _defaultWeight;
    return GestureDetector(
      onHorizontalDragUpdate: (details) => setState(() {
        _angle = (_angle + details.delta.dx * 0.012).clamp(-_maxAngle, _maxAngle);
      }),
      onDoubleTap: () => setState(() => _angle = 0),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          AppSizes.m,
          AppSizes.screenPadding,
          0,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surface, AppColors.accentSoft],
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.m),
                child: CustomPaint(
                  painter: AvatarPainter(
                    heightCm: height,
                    weightKg: weight,
                    angle: _angle,
                    outfit: _outfit,
                  ),
                ),
              ),
            ),
            Positioned(
              left: AppSizes.m,
              top: AppSizes.m,
              child: _Tag(
                icon: Icons.straighten,
                text: sizes?.height == null
                    ? 'Стандартная фигура'
                    : '$height см · $weight кг',
              ),
            ),
            const Positioned(
              right: AppSizes.m,
              top: AppSizes.m,
              child: _Tag(icon: Icons.science_outlined, text: 'Бета'),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: AppSizes.s,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swipe, size: 14, color: AppColors.textSecondary),
                  SizedBox(width: AppSizes.xs),
                  Text('Проведите, чтобы повернуть', style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(List<Product> products) {
    final List<Product> inSlot = products
        .where((product) => Outfit.slotOf(Outfit.kindOf(product)!) == _slot)
        .toList();
    final WornItem? worn = _outfit[_slot];

    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
              itemCount: WearSlot.values.length,
              separatorBuilder: (context, index) => const SizedBox(width: AppSizes.s),
              itemBuilder: (context, index) {
                final WearSlot slot = WearSlot.values[index];
                final bool isSelected = slot == _slot;
                final bool isFilled = _outfit.containsKey(slot);
                return ChoiceChip(
                  selected: isSelected,
                  showCheckmark: false,
                  label: Text(isFilled ? '${slot.label} •' : slot.label),
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
                  onSelected: (_) => setState(() => _slot = slot),
                );
              },
            ),
          ),
          const SizedBox(height: AppSizes.s),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
              itemCount: inSlot.length,
              separatorBuilder: (context, index) => const SizedBox(width: AppSizes.s),
              itemBuilder: (context, index) {
                final Product product = inSlot[index];
                return _WearOption(
                  product: product,
                  isWorn: worn?.product.id == product.id,
                  onTap: () => _toggle(product),
                );
              },
            ),
          ),
          SizedBox(
            height: 48,
            child: worn == null
                ? const Center(
                    child: Text(
                      'Выберите вещь, чтобы примерить и поменять цвет',
                      style: AppTextStyles.caption,
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.screenPadding,
                      vertical: AppSizes.s,
                    ),
                    itemCount: Outfit.palette.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: AppSizes.m),
                    itemBuilder: (context, index) {
                      final Color color = Outfit.palette[index];
                      return _Swatch(
                        color: color,
                        isSelected: worn.color == color,
                        onTap: () => _recolor(color),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.s, vertical: AppSizes.xs),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: AppSizes.xs),
          Text(text, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// Вещь в ленте примерочной: фото и название, рамка у надетой.
class _WearOption extends StatelessWidget {
  const _WearOption({
    required this.product,
    required this.isWorn,
    required this.onTap,
  });

  final Product product;
  final bool isWorn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isWorn,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        onTap: onTap,
        child: Container(
          width: 92,
          padding: const EdgeInsets.all(AppSizes.xs),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            border: Border.all(
              color: isWorn ? AppColors.accent : AppColors.border,
              width: isWorn ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: ProductImage(
                  imageUrl: product.imageUrl,
                  width: double.infinity,
                  borderRadius: AppSizes.radiusS,
                  placeholderIcon: Icons.checkroom,
                ),
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Цвет',
      selected: isSelected,
      button: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.border,
              width: isSelected ? 3 : 1,
            ),
          ),
        ),
      ),
    );
  }
}
