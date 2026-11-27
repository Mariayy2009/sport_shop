import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/feedback_repository.dart';
import '../../data/repositories/moderation_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../models/item_options.dart';
import '../../models/product.dart';
import '../../models/product_filter.dart';
import '../../models/review.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_grid_card.dart';
import '../../widgets/star_rating.dart';
import '../../widgets/user_avatar.dart';

/// Магазин продавца: кто продаёт, рейтинг магазина по отзывам, все его
/// товары и последние отзывы — как витрина продавца на маркетплейсе.
/// [sellerId] null — товары самого магазина SPORT.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, required this.args});

  final ShopArgs args;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopData {
  const _ShopData(this.products, this.reviews, this.rating, this.count, this.seller);

  final List<Product> products;
  final List<Review> reviews;
  final double? rating;
  final int count;
  final SellerSummary? seller;
}

class _ShopScreenState extends State<ShopScreen> {
  late final Future<_ShopData> _future = _load();
  bool _showReviews = false;

  Future<_ShopData> _load() async {
    final int? id = widget.args.sellerId;
    final FeedbackRepository feedback = context.read<FeedbackRepository>();
    final ModerationRepository moderation = context.read<ModerationRepository>();
    final List<Product> products = await context.read<ProductRepository>().getProducts(
          id == null ? const ProductFilter(ownGoods: true) : ProductFilter(sellerId: id),
        );
    final List<Review> reviews = await feedback.getShopReviews(id);
    final (double? rating, int count) = await feedback.shopRating(id);
    SellerSummary? seller;
    if (id != null) {
      for (final SellerSummary s in await moderation.sellers()) {
        if (s.userId == id) seller = s;
      }
    }
    return _ShopData(products, reviews, rating, count, seller);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.args.name,
      navTab: MainTab.catalog,
      body: FutureBuilder<_ShopData>(
        future: _future,
        builder: (context, snapshot) {
          final _ShopData? data = snapshot.data;
          if (data == null) {
            return snapshot.hasError
                ? const EmptyState(icon: Icons.storefront_outlined, title: 'Магазин не открылся')
                : const Center(child: CircularProgressIndicator());
          }
          final List<(Product, ProductVariant?)> cards = [
            for (final Product p in data.products)
              if (p.variants.isEmpty) (p, null) else
                for (final ProductVariant v in p.variants) (p, v),
          ];
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                sliver: SliverList.list(children: [
                  _ShopHeader(args: widget.args, data: data),
                  const SizedBox(height: AppSizes.m),
                  if (data.reviews.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text('Отзывы о магазине', style: AppTextStyles.sectionTitle),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _showReviews = !_showReviews),
                          child: Text(_showReviews ? 'Свернуть' : 'Все (${data.reviews.length})'),
                        ),
                      ],
                    ),
                    for (final Review r in data.reviews.take(_showReviews ? data.reviews.length : 3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSizes.s),
                        child: _ShopReview(review: r),
                      ),
                    const SizedBox(height: AppSizes.s),
                  ],
                  Text('Все товары магазина (${cards.length})', style: AppTextStyles.sectionTitle),
                  const SizedBox(height: AppSizes.s),
                ]),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.screenPadding, 0, AppSizes.screenPadding, AppSizes.l,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSizes.m,
                    crossAxisSpacing: AppSizes.m,
                    childAspectRatio: ProductGridCard.aspectRatio,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (context, index) =>
                      ProductGridCard(product: cards[index].$1, variant: cards[index].$2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({required this.args, required this.data});

  final ShopArgs args;
  final _ShopData data;

  @override
  Widget build(BuildContext context) {
    final SellerSummary? seller = data.seller;
    final bool closed = seller != null && seller.status != SellerStatus.active;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.black,
                child: Text(
                  args.name.characters.first.toUpperCase(),
                  style: AppTextStyles.sectionTitle.copyWith(color: AppColors.white),
                ),
              ),
              const SizedBox(width: AppSizes.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(args.name, style: AppTextStyles.sectionTitle),
                    Text(
                      args.sellerId == null
                          ? 'Официальный магазин площадки'
                          : seller?.since == null
                              ? 'Продавец'
                              : 'Продаёт с ${Formatters.date(seller!.since!)}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (closed)
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.s),
              child: Text(
                'Магазин временно не работает — купить его товары сейчас нельзя',
                style: AppTextStyles.bodySecondary.copyWith(color: AppColors.error),
              ),
            ),
          const SizedBox(height: AppSizes.m),
          Row(
            children: [
              _Stat(
                value: data.rating == null ? '—' : data.rating!.toStringAsFixed(1),
                label: 'рейтинг',
                icon: Icons.star_rounded,
              ),
              _Stat(value: '${data.count}', label: 'отзывов'),
              _Stat(value: '${data.products.length}', label: 'товаров'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.icon});

  final String value;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) Icon(icon, size: 20, color: const Color(0xFFF2A900)),
              Text(value, style: AppTextStyles.sectionTitle),
            ],
          ),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _ShopReview extends StatelessWidget {
  const _ShopReview({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final String name = review.authorName ?? 'Покупатель';
    return AppCard(
      onTap: () => Navigator.of(context)
          .pushNamed(AppRoutes.product, arguments: review.productId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(name: name, imagePath: review.authorAvatarPath, size: 32),
              const SizedBox(width: AppSizes.s),
              Expanded(
                child: Text(name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
              ),
              StarRating(rating: review.rating, size: 14),
            ],
          ),
          if (review.productName != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.xxs),
              child: Text('Товар: ${review.productName}', style: AppTextStyles.caption),
            ),
          if (review.text != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.xxs),
              child: Text(review.text!, style: AppTextStyles.body),
            ),
        ],
      ),
    );
  }
}
