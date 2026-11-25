import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../core/utils/cart_actions.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/product_actions.dart';
import '../../data/repositories/product_repository.dart';
import '../../models/item_options.dart';
import '../../models/product.dart';
import '../../models/try_on.dart';
import '../../models/user_sizes.dart';
import '../../services/games/ball_game.dart';
import '../../services/size_advisor.dart';
import '../../state/cart_state.dart';
import '../../state/compare_state.dart';
import '../../state/favorites_state.dart';
import '../../state/profile_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_feedback_section.dart';
import '../../widgets/photo_gallery.dart';
import '../../widgets/protein_calculator_sheet.dart';
import '../../widgets/product_image.dart';
import '../../widgets/seller_products_section.dart';
import '../../widgets/rating_badge.dart';
import '../../widgets/size_chart_sheet.dart';
import '../../widgets/size_selector.dart';
import '../../widgets/what_else_section.dart';

/// Карточка товара: фото, цена, совет по размеру, характеристики,
/// избранное, сравнение и примерка.
class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, required this.productId});

  final int productId;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late Future<Product?> _future;
  String? _selectedSize;

  /// Выбранный вариант (цвет, модель); null — у товара вариантов нет.
  String? _variant;
  bool _sizeError = false;
  bool _sizeInitialized = false;
  bool _isAdding = false;

  /// Товар, перечитанный после нового отзыва (изменился рейтинг).
  Product? _refreshed;

  static const SizeAdvisor _sizeAdvisor = SizeAdvisor();

  @override
  void initState() {
    super.initState();
    _future = context.read<ProductRepository>().getProductById(widget.productId);
  }

  void _initSize(Product product) {
    if (_sizeInitialized) return;
    _sizeInitialized = true;
    _selectedSize =
        _sizeAdvisor.pickSize(product, context.read<ProfileState>().sizes);
  }

  Future<void> _addToCart(Product product) async {
    if (!product.isAvailable) {
      AppMessages.showWarning(context, 'Товар закончился и недоступен для заказа');
      return;
    }
    if (product.requiresSize && _selectedSize == null) {
      setState(() => _sizeError = true);
      AppMessages.showWarning(context, 'Выберите размер');
      return;
    }
    setState(() => _isAdding = true);
    await CartActions.addToCart(
      context,
      product,
      size: _selectedSize,
      variant: _variant,
    );
    if (mounted) setState(() => _isAdding = false);
  }

  Future<void> _refreshProduct() async {
    final Product? product =
        await context.read<ProductRepository>().getProductById(widget.productId);
    if (mounted && product != null) setState(() => _refreshed = product);
  }

  void _showCertificate() {
    AppMessages.showInfoDialog(
      context,
      title: 'Сертификат соответствия',
      message: 'Товар сертифицирован. Электронная копия сертификата будет '
          'доступна для скачивания в следующей версии приложения, '
          'бумажную копию можно запросить при получении заказа.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Product?>(
      future: _future,
      builder: (context, snapshot) {
        final Product? product = _refreshed ?? snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppScaffold(
            title: 'Товар',
            navTab: MainTab.catalog,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (product == null) {
          return AppScaffold(
            title: 'Товар',
            navTab: MainTab.catalog,
            body: EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Товар не найден',
              message: 'Возможно, он был удалён из каталога',
              actionText: 'Назад',
              onAction: () => Navigator.of(context).maybePop(),
            ),
          );
        }
        _initSize(product);
        return AppScaffold(
          title: 'Товар',
          navTab: MainTab.catalog,
          titleTrailing: _TitleActions(product: product),
          bottomAction: CustomButton(
            text: product.isAvailable ? 'Положить в корзину' : 'Нет в наличии',
            isLoading: _isAdding,
            onPressed: () => _addToCart(product),
          ),
          body: _buildContent(product),
        );
      },
    );
  }

  /// Для футбольных и волейбольных мячей — вход в игру «Набей мяч».
  static BallGameMode? _gameModeFor(Product product) {
    if (!product.name.toLowerCase().contains('мяч')) return null;
    return switch (product.sportName) {
      'Футбол' => BallGameMode.football,
      'Волейбол' => BallGameMode.volleyballLow,
      'Баскетбол' => BallGameMode.basketball,
      _ => null,
    };
  }

  Widget _buildContent(Product product) {
    final UserSizes? sizes = context.watch<ProfileState>().sizes;
    final Set<int> cartIds = context.watch<CartState>().productIds;
    final SizeAdvice? advice = _sizeAdvisor.advise(product, sizes);
    final TryOnSupport tryOn = TryOnSupport.of(product);

    return ListView(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        PhotoGallery(
          // Фото вариантов тоже листаются, даже если их нет в галерее.
          images: [
            ...product.images,
            for (final ProductVariant variant in product.variants)
              if (!product.images.contains(variant.image)) variant.image,
          ],
          height: 280,
          padding: const EdgeInsets.all(AppSizes.m),
          selectedImage: product.variantNamed(_variant)?.image,
        ),
        const SizedBox(height: AppSizes.l),
        Row(
          children: [
            Expanded(
              child: Text(
                [product.brand, product.sportName].whereType<String>().join(' · '),
                style: AppTextStyles.bodySecondary,
              ),
            ),
            RatingBadge(rating: product.rating),
            if (product.reviewsCount > 0)
              Text(
                '  ·  ${product.reviewsCount} '
                '${Formatters.plural(product.reviewsCount, 'отзыв', 'отзыва', 'отзывов')}',
                style: AppTextStyles.caption,
              ),
          ],
        ),
        if (product.isBlocked) ...[
          const SizedBox(height: AppSizes.s),
          Container(
            padding: const EdgeInsets.all(AppSizes.m),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
            child: Text(
              'Товар снят с продажи администратором'
              '${product.blockReason == null ? '' : ': ${product.blockReason}'}',
              style: AppTextStyles.body.copyWith(color: AppColors.error),
            ),
          ),
        ],
        const SizedBox(height: AppSizes.xs),
        Text(product.name, style: AppTextStyles.sectionTitle.copyWith(fontSize: 20)),
        const SizedBox(height: AppSizes.xxs),
        Row(
          children: [
            const Icon(Icons.storefront_outlined, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: AppSizes.xxs),
            Text('Продавец: ${product.sellerTitle}', style: AppTextStyles.bodySecondary),
          ],
        ),
        const SizedBox(height: AppSizes.xs),
        Text(Formatters.price(product.price), style: AppTextStyles.priceLarge),
        const SizedBox(height: AppSizes.xs),
        Text(
          !product.isAvailable
              ? 'Нет в наличии'
              : product.isLowStock
                  ? 'Мало осталось: ${product.stock} шт. — успейте купить'
                  : 'В наличии: ${product.stock} шт.',
          style: AppTextStyles.bodySecondary.copyWith(
            color: product.isAvailable && !product.isLowStock
                ? AppColors.success
                : AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (product.description != null) ...[
          const SizedBox(height: AppSizes.m),
          Text(product.description!, style: AppTextStyles.body),
        ],
        if (product.variants.isNotEmpty) ...[
          const SizedBox(height: AppSizes.l),
          Text(
            'Цвет и модель: ${_variant ?? product.variants.first.name}',
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: AppSizes.s),
          _VariantPicker(
            variants: product.variants,
            selected: _variant ?? product.variants.first.name,
            onSelected: (name) => setState(() => _variant = name),
          ),
        ],
        if (product.requiresSize) ...[
          const SizedBox(height: AppSizes.l),
          Row(
            children: [
              const Expanded(
                child: Text('Размер', style: AppTextStyles.sectionTitle),
              ),
              TextButton(
                onPressed: () => SizeChartSheet.show(context, product),
                child: const Text('Таблица размеров'),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.s),
          SizeSelector(
            sizes: product.availableSizes,
            selected: _selectedSize,
            hasError: _sizeError,
            onSelected: (size) => setState(() {
              _selectedSize = size;
              _sizeError = false;
            }),
          ),
          if (_sizeError)
            const Padding(
              padding: EdgeInsets.only(top: AppSizes.xs),
              child: Text('Выберите размер', style: AppTextStyles.fieldError),
            ),
          const SizedBox(height: AppSizes.m),
          _SizeAdviceCard(
            advice: advice,
            isSelected: advice != null && advice.size == _selectedSize,
            onApply: advice == null
                ? () => Navigator.of(context).pushNamed(AppRoutes.editProfile)
                : () => setState(() {
                      _selectedSize = advice.size;
                      _sizeError = false;
                    }),
          ),
        ],
        const SizedBox(height: AppSizes.m),
        OutlinedButton.icon(
          // Для обуви, инвентаря и аксессуаров кнопка объясняет,
          // почему примерка недоступна.
          onPressed: tryOn.any
              ? () => Navigator.of(context)
                  .pushNamed(AppRoutes.tryOn, arguments: product.id)
              : () => AppMessages.showInfoDialog(
                    context,
                    title: 'Примерка недоступна',
                    message: tryOn.reason ?? 'Этот товар нельзя примерить',
                  ),
          icon: const Icon(Icons.checkroom, size: 18),
          label: Text(tryOn.any ? 'Примерить' : 'Примерка недоступна'),
        ),
        if (_gameModeFor(product) case final BallGameMode mode) ...[
          const SizedBox(height: AppSizes.s),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.ballGame, arguments: mode),
            icon: const Icon(Icons.sports_soccer, size: 18),
            label: const Text('Сыграть с мячом: набей через камеру'),
          ),
        ],
        const SizedBox(height: AppSizes.l),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Характеристики', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSizes.s),
              if (product.brand != null)
                _InfoRow(label: 'Бренд', value: product.brand!),
              if (product.material != null)
                _InfoRow(label: 'Материал', value: product.material!),
              _InfoRow(label: 'Категория', value: product.categoryName ?? '—'),
              _InfoRow(label: 'Вид спорта', value: product.sportName ?? '—'),
              _InfoRow(
                label: 'Размеры',
                value: product.requiresSize
                    ? product.availableSizes.join(', ')
                    : 'Без размера',
              ),
              _InfoRow(
                label: 'Артикул',
                value: 'SP-${product.id.toString().padLeft(5, '0')}',
              ),
              _InfoRow(
                label: 'Наличие',
                value: product.isAvailable ? '${product.stock} шт.' : 'Нет',
              ),
            ],
          ),
        ),
        if (product.composition != null) ...[
          const SizedBox(height: AppSizes.m),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Состав', style: AppTextStyles.sectionTitle),
                const SizedBox(height: AppSizes.xs),
                Text(product.composition!, style: AppTextStyles.body),
                if (product.diet.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.s),
                  Wrap(
                    spacing: AppSizes.xs,
                    runSpacing: AppSizes.xs,
                    children: [
                      for (final String tag in product.diet)
                        if (DietTag.labels[tag] case final String label)
                          Chip(
                            avatar: const Icon(Icons.check, size: 16, color: AppColors.success),
                            label: Text(label),
                            visualDensity: VisualDensity.compact,
                          ),
                    ],
                  ),
                ],
                if (product.proteinPortion != null) ...[
                  const SizedBox(height: AppSizes.s),
                  OutlinedButton.icon(
                    onPressed: () => ProteinCalculatorSheet.show(context, product),
                    icon: const Icon(Icons.calculate_outlined),
                    label: const Text('Сколько порций нужно мне?'),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSizes.m),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Прикреплённые файлы', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSizes.xs),
              _FileRow(
                title: 'Таблица размеров',
                subtitle: 'Подбор размера',
                onTap: () => SizeChartSheet.show(context, product),
              ),
              _FileRow(
                title: 'Сертификат.pdf',
                subtitle: 'Сертификат соответствия',
                onTap: _showCertificate,
              ),
            ],
          ),
        ),
        SellerProductsSection(product: product),
        ProductFeedbackSection(
          product: product,
          onRatingChanged: _refreshProduct,
        ),
        WhatElseSection(
          title: 'С этим товаром покупают',
          sportId: product.sportId,
          experienceYears: sizes?.experienceYears ?? 0,
          excludeProductIds: {product.id!, ...cartIds},
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodySecondary)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodySecondary
                  .copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusS),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.s),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf_outlined, color: AppColors.logoRed),
            const SizedBox(width: AppSizes.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.body),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            const Icon(Icons.download_outlined, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Кнопки в строке заголовка: избранное и сравнение.
class _TitleActions extends StatelessWidget {
  const _TitleActions({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final bool isFavorite = context.watch<FavoritesState>().contains(product.id);
    final bool inCompare = context.watch<CompareState>().contains(product.id);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: inCompare ? 'Убрать из сравнения' : 'Сравнить',
          onPressed: () => ProductActions.toggleCompare(context, product),
          icon: Icon(
            Icons.compare_arrows,
            color: inCompare ? AppColors.accent : AppColors.textPrimary,
          ),
        ),
        IconButton(
          tooltip: isFavorite ? 'Убрать из избранного' : 'В избранное',
          onPressed: () => ProductActions.toggleFavorite(context, product),
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? AppColors.favorite : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Умный подбор размера: рекомендация с объяснением
/// или приглашение заполнить параметры в профиле.
class _SizeAdviceCard extends StatelessWidget {
  const _SizeAdviceCard({
    required this.advice,
    required this.isSelected,
    required this.onApply,
  });

  final SizeAdvice? advice;
  final bool isSelected;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final SizeAdvice? advice = this.advice;
    return Container(
      padding: const EdgeInsets.all(AppSizes.m),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.straighten, color: AppColors.accentDark, size: 20),
          const SizedBox(width: AppSizes.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  advice == null
                      ? 'Подберём размер за вас'
                      : 'Рекомендуем размер ${advice.size}',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.accentDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSizes.xxs),
                Text(
                  advice?.explanation ??
                      'Укажите рост, вес и размеры в профиле — и мы '
                          'подскажем размер для каждого товара.',
                  style: AppTextStyles.bodySecondary.copyWith(height: 1.35),
                ),
                if (advice == null || !isSelected) ...[
                  const SizedBox(height: AppSizes.s),
                  TextButton(
                    onPressed: onApply,
                    child: Text(
                      advice == null
                          ? 'Заполнить профиль'
                          : 'Выбрать ${advice.size}',
                      style: const TextStyle(color: AppColors.accentDark),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Варианты товара: миниатюры фото с подписью, выбранный — в рамке.
class _VariantPicker extends StatelessWidget {
  const _VariantPicker({
    required this.variants,
    required this.selected,
    required this.onSelected,
  });

  final List<ProductVariant> variants;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: variants.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppSizes.s),
        itemBuilder: (context, index) {
          final ProductVariant variant = variants[index];
          final bool isSelected = variant.name == selected;
          return Semantics(
            button: true,
            selected: isSelected,
            label: variant.name,
            child: GestureDetector(
              onTap: () => onSelected(variant.name),
              child: SizedBox(
                width: 68,
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppSizes.radiusS),
                        border: Border.all(
                          color: isSelected ? AppColors.black : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ProductImage(
                        imageUrl: variant.image,
                        borderRadius: AppSizes.radiusS - 2,
                      ),
                    ),
                    const SizedBox(height: AppSizes.xxs),
                    Text(
                      variant.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
