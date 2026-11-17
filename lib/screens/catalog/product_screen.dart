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
import '../../models/product.dart';
import '../../models/try_on.dart';
import '../../models/user_sizes.dart';
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
import '../../widgets/product_image.dart';
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
    await CartActions.addToCart(context, product, size: _selectedSize);
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

  Widget _buildContent(Product product) {
    final UserSizes? sizes = context.watch<ProfileState>().sizes;
    final Set<int> cartIds = context.watch<CartState>().productIds;
    final SizeAdvice? advice = _sizeAdvisor.advise(product, sizes);
    final TryOnSupport tryOn = TryOnSupport.of(product);

    return ListView(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        Container(
          height: 280,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
          ),
          padding: const EdgeInsets.all(AppSizes.m),
          child: ProductImage(
            imageUrl: product.imageUrl,
            fit: BoxFit.contain,
            placeholderIcon: Icons.image_outlined,
          ),
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
        const SizedBox(height: AppSizes.xs),
        Text(product.name, style: AppTextStyles.sectionTitle.copyWith(fontSize: 20)),
        const SizedBox(height: AppSizes.xs),
        Text(Formatters.price(product.price), style: AppTextStyles.priceLarge),
        const SizedBox(height: AppSizes.xs),
        Text(
          product.isAvailable
              ? 'В наличии: ${product.stock} шт.'
              : 'Нет в наличии',
          style: AppTextStyles.bodySecondary.copyWith(
            color: product.isAvailable ? AppColors.success : AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (product.description != null) ...[
          const SizedBox(height: AppSizes.m),
          Text(product.description!, style: AppTextStyles.body),
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
