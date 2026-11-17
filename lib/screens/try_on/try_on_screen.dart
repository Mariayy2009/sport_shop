import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/product_repository.dart';
import '../../models/product.dart';
import '../../models/try_on.dart';
import '../../services/size_advisor.dart';
import '../../state/profile_state.dart';
import '../../state/try_on_controller.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_image.dart';
import '../../widgets/try_on_product_strip.dart';

/// Примерочная: выбор способа примерки для товара.
///
///  • «Примерить по фотографии» — нейросеть надевает вещь на фото.
///  • «Живая примерка» — 3D-модель вещи следует за телом в камере.
class TryOnScreen extends StatefulWidget {
  const TryOnScreen({super.key, this.productId});

  /// Товар, с карточки которого открыли примерку; null — выбрать из списка.
  final int? productId;

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> {
  late final Future<List<Product>> _future = _load();
  Product? _product;

  /// Все товары каталога; для списка выбора берутся только примеряемые.
  Future<List<Product>> _load() async {
    final List<Product> all =
        await context.read<ProductRepository>().getProducts();
    for (final Product product in all) {
      if (product.id == widget.productId) _product = product;
    }
    final List<Product> wearable =
        all.where((product) => TryOnSupport.of(product).any).toList();
    // Без товара на входе начинаем с первого, который можно примерить.
    _product ??= wearable.firstOrNull;
    return wearable;
  }

  void _open(String route, Product product) {
    context.read<TryOnController>().selectProduct(product);
    Navigator.of(context).pushNamed(route, arguments: product.id);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Примерочная',
      navTab: MainTab.home,
      body: FutureBuilder<List<Product>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final Product? product = _product;
          if (product == null) {
            return const EmptyState(
              icon: Icons.checkroom,
              title: 'Нечего примерить',
              message: 'В каталоге пока нет одежды для примерки',
            );
          }
          final TryOnSupport support = TryOnSupport.of(product);
          return ListView(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            children: [
              _ProductHeader(product: product),
              const SizedBox(height: AppSizes.l),
              if (support.reason != null) ...[
                _Notice(text: support.reason!),
                const SizedBox(height: AppSizes.m),
              ],
              _ModeCard(
                icon: Icons.auto_awesome,
                title: 'Примерить по фотографии',
                description: 'Нейросеть наденет эту вещь на вашу фотографию: '
                    'сохранит лицо, позу и детали одежды.',
                details: 'Нейросеть работает на вашем ноутбуке: '
                    '5–10 минут на одно фото',
                enabled: support.photo,
                onTap: () => _open(AppRoutes.photoTryOn, product),
              ),
              const SizedBox(height: AppSizes.m),
              _ModeCard(
                icon: Icons.videocam_outlined,
                title: 'Живая примерка',
                description: '3D-модель вещи появится на вас в камере '
                    'и будет двигаться вместе с вами.',
                details: 'Работает в реальном времени, без интернета',
                enabled: support.live,
                onTap: () => _open(AppRoutes.liveTryOn, product),
              ),
              const SizedBox(height: AppSizes.l),
              const Text('Примерить другой товар', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSizes.s),
              TryOnProductStrip(
                products: snapshot.data ?? const [],
                selectedId: product.id,
                onSelected: (selected) => setState(() => _product = selected),
              ),
              const SizedBox(height: AppSizes.l),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 16, color: AppColors.textSecondary),
                  SizedBox(width: AppSizes.s),
                  Expanded(
                    child: Text(
                      'Ваши фото и видео не уходят в интернет: камера '
                      'обрабатывается на телефоне, фотографии — на вашем '
                      'ноутбуке в домашней сети.',
                      style: AppTextStyles.caption,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({required this.product});

  final Product product;

  static const SizeAdvisor _sizeAdvisor = SizeAdvisor();

  @override
  Widget build(BuildContext context) {
    final String? size =
        _sizeAdvisor.pickSize(product, context.watch<ProfileState>().sizes);
    return AppCard(
      onTap: () => Navigator.of(context)
          .pushNamed(AppRoutes.product, arguments: product.id),
      child: Row(
        children: [
          ProductImage(imageUrl: product.imageUrl, width: 72, height: 72),
          const SizedBox(width: AppSizes.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [product.categoryName, product.sportName]
                      .whereType<String>()
                      .join(' · '),
                  style: AppTextStyles.caption,
                ),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sectionTitle,
                ),
                const SizedBox(height: AppSizes.xxs),
                Row(
                  children: [
                    Text(Formatters.price(product.price), style: AppTextStyles.price),
                    if (size != null) ...[
                      const SizedBox(width: AppSizes.s),
                      Text('· ваш размер $size', style: AppTextStyles.bodySecondary),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.m),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.accentDark),
          const SizedBox(width: AppSizes.s),
          Expanded(child: Text(text, style: AppTextStyles.bodySecondary)),
        ],
      ),
    );
  }
}

/// Большая карточка способа примерки.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.details,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String details;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(AppSizes.radiusL);
    final Color foreground = enabled ? AppColors.white : AppColors.textSecondary;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: enabled ? AppColors.black : AppColors.divider,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.l),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: enabled ? AppColors.accent : AppColors.border,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.white),
                ),
                const SizedBox(width: AppSizes.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.sectionTitle.copyWith(color: foreground),
                      ),
                      const SizedBox(height: AppSizes.xxs),
                      Text(
                        enabled ? description : 'Недоступно для этого товара',
                        style: AppTextStyles.bodySecondary.copyWith(
                          color: foreground.withValues(alpha: 0.85),
                        ),
                      ),
                      if (enabled) ...[
                        const SizedBox(height: AppSizes.xs),
                        Text(
                          details,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (enabled) const Icon(Icons.arrow_forward, color: AppColors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
