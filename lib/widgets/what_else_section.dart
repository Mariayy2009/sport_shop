import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_sizes.dart';
import '../core/routes/app_routes.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/cart_actions.dart';
import '../models/recommended_product.dart';
import '../services/recommendation_service.dart';
import 'product_card.dart';

/// Блок «Что ещё купить?» (таблица recommendations):
/// по виду спорта и стажу, без товаров, которые уже выбраны.
class WhatElseSection extends StatefulWidget {
  const WhatElseSection({
    super.key,
    required this.sportId,
    required this.experienceYears,
    this.excludeProductIds = const {},
    this.title = 'Что ещё купить?',
  });

  final int sportId;
  final int experienceYears;
  final Set<int> excludeProductIds;
  final String title;

  @override
  State<WhatElseSection> createState() => _WhatElseSectionState();
}

class _WhatElseSectionState extends State<WhatElseSection> {
  late Future<List<RecommendedProduct>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(WhatElseSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sportId != widget.sportId ||
        oldWidget.experienceYears != widget.experienceYears ||
        !setEquals(oldWidget.excludeProductIds, widget.excludeProductIds)) {
      _future = _load();
    }
  }

  Future<List<RecommendedProduct>> _load() {
    return context.read<RecommendationService>().getWhatElseToBuy(
          sportId: widget.sportId,
          experienceYears: widget.experienceYears,
          excludeProductIds: widget.excludeProductIds,
        );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RecommendedProduct>>(
      future: _future,
      builder: (context, snapshot) {
        final List<RecommendedProduct> items = snapshot.data ?? const [];
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSizes.l),
            Text(widget.title, style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSizes.s),
            SizedBox(
              height: 230,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(width: AppSizes.s),
                itemBuilder: (context, index) {
                  final RecommendedProduct item = items[index];
                  return ProductCard(
                    product: item.product,
                    caption: item.reason,
                    onTap: () => Navigator.of(context).pushNamed(
                      AppRoutes.product,
                      arguments: item.product.id,
                    ),
                    onAdd: () => CartActions.addToCart(context, item.product),
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
