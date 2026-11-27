import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_sizes.dart';
import '../core/routes/app_routes.dart';
import '../core/utils/cart_actions.dart';
import '../data/repositories/product_repository.dart';
import '../models/product.dart';
import 'product_card.dart';
import 'section_header.dart';

/// «Ещё у продавца»: другие товары того же продавца, как на
/// маркетплейсах. Сначала — варианты того же вида (другие кимоно у
/// продавца кимоно), потом остальное.
class SellerProductsSection extends StatefulWidget {
  const SellerProductsSection({super.key, required this.product});

  final Product product;

  /// Больше не показываем — блок про варианты, а не весь магазин.
  static const int maxItems = 8;

  /// Товары того же продавца (магазина) из [all], без самого товара;
  /// сначала та же категория и вид спорта. У товаров SPORT продавца нет —
  /// тогда «тот же магазин» — это тот же бренд, чтобы не показывать весь
  /// каталог.
  static List<Product> pick(Product product, List<Product> all) {
    final bool own = product.sellerId == null;
    if (own && (product.brand == null || product.brand!.isEmpty)) return const [];
    final List<Product> same = all
        .where((other) =>
            other.id != product.id &&
            (own
                ? other.sellerId == null && other.brand == product.brand
                : other.sellerId == product.sellerId))
        .toList();
    int rank(Product other) =>
        (other.categoryId == product.categoryId ? 0 : 2) +
        (other.sportId == product.sportId ? 0 : 1);
    same.sort((a, b) => rank(a).compareTo(rank(b)));
    return same.take(maxItems).toList();
  }

  @override
  State<SellerProductsSection> createState() => _SellerProductsSectionState();
}

class _SellerProductsSectionState extends State<SellerProductsSection> {
  late Future<List<Product>> _future = _load();

  Future<List<Product>> _load() async => SellerProductsSection.pick(
        widget.product,
        await context.read<ProductRepository>().getProducts(),
      );

  @override
  void didUpdateWidget(SellerProductsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: _future,
      builder: (context, snapshot) {
        final List<Product> items = snapshot.data ?? const [];
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSizes.l),
            SectionHeader(
              title: 'Ещё у продавца ${widget.product.sellerTitle}',
              actionText: 'Магазин',
              onAction: () => Navigator.of(context).pushNamed(
                AppRoutes.shop,
                arguments: ShopArgs(widget.product.sellerId, widget.product.sellerTitle),
              ),
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
                  final Product item = items[index];
                  return ProductCard(
                    product: item,
                    caption: item.categoryName,
                    onTap: () => Navigator.of(context)
                        .pushNamed(AppRoutes.product, arguments: item.id),
                    onAdd: () => CartActions.addToCart(context, item),
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
