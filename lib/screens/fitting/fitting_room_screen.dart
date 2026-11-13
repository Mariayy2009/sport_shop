import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/product_actions.dart';
import '../../data/repositories/product_repository.dart';
import '../../models/fitting_photos.dart';
import '../../models/outfit.dart';
import '../../models/product.dart';
import '../../models/user_sizes.dart';
import '../../services/size_advisor.dart';
import '../../state/fitting_state.dart';
import '../../state/profile_state.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/avatar_painter.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/product_image.dart';

/// Виртуальная примерочная.
///
/// Два режима:
///  • «На моём фото» — одежда каталога накладывается на фото пользователя
///    в полный рост. Положение, размер и ширину одежды пользователь один
///    раз подгоняет под себя, подгонка сохраняется.
///  • «Манекен» — фигура по росту и весу из профиля с фото лица,
///    её можно поворачивать жестом.
/// В обоих режимах можно менять вещи и их цвет.
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

  /// Режим «на моём фото»; без фото в полный рост работает манекен.
  bool _onPhoto = true;

  /// Идёт подгонка одежды под фото.
  bool _isAdjusting = false;

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

  void _openPhotos() =>
      Navigator.of(context).pushNamed(AppRoutes.fittingPhotos);

  void _finishAdjusting() {
    context.read<FittingState>().persistFit();
    setState(() => _isAdjusting = false);
  }

  @override
  Widget build(BuildContext context) {
    final UserSizes? sizes = context.watch<ProfileState>().sizes;
    final FittingPhotos? photos = context.watch<FittingState>().photos;
    final bool photoMode = _onPhoto && (photos?.hasBody ?? false);
    final double total =
        _outfit.values.fold(0, (sum, item) => sum + item.product.price);

    return AppScaffold(
      title: 'Примерочная',
      navTab: MainTab.home,
      titleTrailing: TextButton.icon(
        onPressed: _openPhotos,
        icon: const Icon(Icons.photo_camera_outlined, size: 18),
        label: const Text('Мои фото'),
      ),
      bottomAction: _outfit.isEmpty || _isAdjusting
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
              _buildModeSwitch(photos),
              Expanded(
                child: photoMode
                    ? _buildPhotoStage(photos!)
                    : _buildStage(sizes, photos),
              ),
              if (photoMode && _isAdjusting)
                _buildAdjustPanel(photos!)
              else
                _buildControls(products),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModeSwitch(FittingPhotos? photos) {
    final bool hasBody = photos?.hasBody ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        AppSizes.m,
        AppSizes.screenPadding,
        0,
      ),
      child: SegmentedButton<bool>(
        showSelectedIcon: false,
        expandedInsets: EdgeInsets.zero,
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.surface,
          selectedBackgroundColor: AppColors.black,
          selectedForegroundColor: AppColors.white,
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          textStyle:
              AppTextStyles.bodySecondary.copyWith(fontWeight: FontWeight.w600),
        ),
        segments: const [
          ButtonSegment(
            value: true,
            icon: Icon(Icons.person_outline, size: 18),
            label: Text('На моём фото'),
          ),
          ButtonSegment(
            value: false,
            icon: Icon(Icons.accessibility_new, size: 18),
            label: Text('Манекен'),
          ),
        ],
        selected: {_onPhoto && hasBody},
        onSelectionChanged: (value) {
          if (value.first && !hasBody) {
            // Фото ещё нет — сначала его нужно загрузить.
            _openPhotos();
            return;
          }
          setState(() {
            _onPhoto = value.first;
            _isAdjusting = false;
          });
        },
      ),
    );
  }

  /// Фото пользователя с одеждой поверх. Все размеры — в долях высоты
  /// сцены, поэтому подгонка не «съезжает» при изменении её размера.
  Widget _buildPhotoStage(FittingPhotos photos) {
    final FittingState fitting = context.read<FittingState>();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        AppSizes.m,
        AppSizes.screenPadding,
        0,
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double stageHeight = constraints.maxHeight;
          final double figureHeight = stageHeight * 0.9 * photos.fitScale;
          final double figureWidth = figureHeight * 0.7;
          return GestureDetector(
            // В режиме подгонки одежду двигают пальцем.
            onPanUpdate: _isAdjusting
                ? (details) => fitting.updateFit(
                      dx: photos.fitDx + details.delta.dx / stageHeight,
                      dy: photos.fitDy + details.delta.dy / stageHeight,
                    )
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.file(
                    File(photos.bodyPath!),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Text(
                        'Фото не найдено — загрузите его заново',
                        style: TextStyle(color: AppColors.white),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: constraints.maxWidth / 2 +
                      photos.fitDx * stageHeight -
                      figureWidth / 2,
                  top: stageHeight / 2 +
                      photos.fitDy * stageHeight -
                      figureHeight / 2,
                  width: figureWidth,
                  height: figureHeight,
                  child: IgnorePointer(
                    child: Stack(
                      children: [
                        if (_isAdjusting)
                          // Контур фигуры помогает совместить одежду с телом.
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0.4,
                              child: CustomPaint(
                                painter: AvatarPainter(
                                  heightCm: _defaultHeight,
                                  weightKg: _defaultWeight,
                                  angle: 0,
                                  outfit: const {},
                                  widthFactor: photos.fitWidth,
                                  fillHeight: true,
                                ),
                              ),
                            ),
                          ),
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.95,
                            child: CustomPaint(
                              painter: AvatarPainter(
                                heightCm: _defaultHeight,
                                weightKg: _defaultWeight,
                                angle: 0,
                                outfit: _outfit,
                                showBody: false,
                                widthFactor: photos.fitWidth,
                                fillHeight: true,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!_isAdjusting)
                  Positioned(
                    right: AppSizes.m,
                    top: AppSizes.m,
                    child: Material(
                      color: AppColors.surface,
                      shape: const StadiumBorder(),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: () => setState(() => _isAdjusting = true),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSizes.m,
                            vertical: AppSizes.s,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune, size: 16),
                              SizedBox(width: AppSizes.xs),
                              Text('Подогнать', style: AppTextStyles.bodySecondary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Панель подгонки: размер и ширина одежды, положение — жестом на фото.
  Widget _buildAdjustPanel(FittingPhotos photos) {
    final FittingState fitting = context.read<FittingState>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        AppSizes.m,
        AppSizes.screenPadding,
        AppSizes.s,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Совместите контур с собой: двигайте его пальцем, '
            'а размер и ширину настройте ползунками.',
            style: AppTextStyles.bodySecondary,
          ),
          _FitSlider(
            label: 'Размер',
            value: photos.fitScale,
            min: FittingPhotos.minScale,
            max: FittingPhotos.maxScale,
            onChanged: (value) => fitting.updateFit(scale: value),
          ),
          _FitSlider(
            label: 'Ширина',
            value: photos.fitWidth,
            min: FittingPhotos.minWidth,
            max: FittingPhotos.maxWidth,
            onChanged: (value) => fitting.updateFit(width: value),
          ),
          CustomButton(text: 'Готово', onPressed: _finishAdjusting),
        ],
      ),
    );
  }

  /// Сцена с манекеном: поворот — горизонтальным жестом.
  Widget _buildStage(UserSizes? sizes, FittingPhotos? photos) {
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
          color: AppColors.accentSoft,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.m),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final AvatarPainter painter = AvatarPainter(
                      heightCm: height,
                      weightKg: weight,
                      angle: _angle,
                      outfit: _outfit,
                    );
                    final String? facePath = photos?.facePath;
                    return Stack(
                      children: [
                        Positioned.fill(child: CustomPaint(painter: painter)),
                        // Фото лица — на голове манекена.
                        if (facePath != null)
                          Positioned.fromRect(
                            rect: painter.headRect(constraints.biggest),
                            child: ClipOval(
                              child: Image.file(
                                File(facePath),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
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

class _FitSlider extends StatelessWidget {
  const _FitSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(label, style: AppTextStyles.bodySecondary),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: AppColors.accent,
            label: label,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
