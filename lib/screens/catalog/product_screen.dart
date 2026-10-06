import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../core/utils/cart_actions.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/product_repository.dart';
import '../../models/product.dart';
import '../../models/user_sizes.dart';
import '../../state/cart_state.dart';
import '../../state/profile_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_image.dart';
import '../../widgets/size_chart_sheet.dart';
import '../../widgets/size_selector.dart';
import '../../widgets/what_else_section.dart';

/// Карточка товара (фрейм Figma «товар»).
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

  @override
  void initState() {
    super.initState();
    _future = context.read<ProductRepository>().getProductById(widget.productId);
  }

  void _initSize(Product product) {
    if (_sizeInitialized) return;
    _sizeInitialized = true;
    final UserSizes? sizes = context.read<ProfileState>().sizes;
    _selectedSize = product.pickSize(
      clothingSize: sizes?.clothingSize,
      shoeSize: sizes?.shoeSize,
    );
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
        final Product? product = snapshot.data;
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
        Text(product.name, style: AppTextStyles.sectionTitle.copyWith(fontSize: 18)),
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
        ],
        const SizedBox(height: AppSizes.l),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Характеристики', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSizes.s),
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
