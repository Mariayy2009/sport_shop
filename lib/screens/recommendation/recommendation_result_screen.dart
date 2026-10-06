import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/sport_visuals.dart';
import '../../core/errors/app_exception.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../core/utils/cart_actions.dart';
import '../../core/utils/formatters.dart';
import '../../models/recommendation_request.dart';
import '../../models/recommended_product.dart';
import '../../state/cart_state.dart';
import '../../state/product_state.dart';
import '../../state/recommendation_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/recommendation_card.dart';

/// Результат AI-подбора (фрейм Figma «ии5»):
/// обязательные товары и рекомендации с причинами.
class RecommendationResultScreen extends StatefulWidget {
  const RecommendationResultScreen({super.key});

  @override
  State<RecommendationResultScreen> createState() =>
      _RecommendationResultScreenState();
}

class _RecommendationResultScreenState
    extends State<RecommendationResultScreen> {
  bool _isAddingAll = false;

  /// Добавляет все товары, которых ещё нет в корзине.
  /// Размер подставляется из ответов опроса.
  Future<void> _addAll(RecommendationState state) async {
    final CartState cart = context.read<CartState>();
    final NavigatorState navigator = Navigator.of(context);
    final RecommendationRequest? request = state.lastRequest;
    setState(() => _isAddingAll = true);

    int added = 0;
    final List<String> skipped = [];
    for (final RecommendedProduct item in state.results) {
      if (cart.containsProduct(item.product.id)) continue;
      final String? size = item.product.pickSize(
            clothingSize: request?.clothingSize,
            shoeSize: request?.shoeSize,
          ) ??
          item.product.availableSizes.firstOrNull;
      try {
        await cart.add(item.product, size: size);
        added++;
      } on AppException {
        skipped.add(item.product.name);
      }
    }

    if (!mounted) return;
    setState(() => _isAddingAll = false);
    if (added == 0 && skipped.isEmpty) {
      AppMessages.showInfo(context, 'Все товары подборки уже в корзине');
      return;
    }
    AppMessages.show(
      context,
      skipped.isEmpty
          ? 'Добавлено в корзину: ${Formatters.itemsCount(added)}'
          : 'Добавлено: $added. Недоступны: ${skipped.join(', ')}',
      type: skipped.isEmpty ? MessageType.success : MessageType.warning,
      actionLabel: 'Корзина',
      onAction: () => navigator.pushNamedAndRemoveUntil(
        AppRoutes.main,
        (route) => false,
        arguments: MainTab.basket,
      ),
    );
  }

  Future<void> _addOne(RecommendedProduct item) async {
    final RecommendationRequest? request =
        context.read<RecommendationState>().lastRequest;
    final String? size = item.product.pickSize(
      clothingSize: request?.clothingSize,
      shoeSize: request?.shoeSize,
    );
    await CartActions.addToCart(
      context,
      item.product,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final RecommendationState state = context.watch<RecommendationState>();
    final CartState cart = context.watch<CartState>();
    final RecommendationRequest? request = state.lastRequest;
    final String? sportName =
        context.watch<ProductState>().sportName(request?.sportId);
    final String title =
        'Твоя экипировка для ${SportVisuals.of(sportName).genitive}';

    if (state.isLoading) {
      return AppScaffold(
        title: title,
        navTab: MainTab.ai,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (state.error != null || state.results.isEmpty || request == null) {
      return AppScaffold(
        title: title,
        navTab: MainTab.ai,
        body: EmptyState(
          icon: Icons.auto_awesome_outlined,
          title: state.error ?? 'Подходящих товаров не найдено',
          message: 'Попробуйте изменить вид спорта или параметры',
          actionText: 'Изменить параметры',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    final List<RecommendedProduct> mandatory = state.mandatory;
    final List<RecommendedProduct> optional = state.optional;
    final double overBudget = state.mandatoryTotal - (request.budget ?? 0);

    return AppScaffold(
      title: title,
      navTab: MainTab.ai,
      bottomAction: CustomButton(
        text: 'Добавить всё — ${Formatters.price(state.totalPrice)}',
        isLoading: _isAddingAll,
        onPressed: () => _addAll(state),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        children: [
          Text(
            'Уровень: ${request.level.label.toLowerCase()} · '
            'Стаж: ${Formatters.years(request.experienceYears)} · '
            'Размер: ${request.clothingSize ?? '—'}',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: AppSizes.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Бюджет: до ${Formatters.price(request.budget ?? 0)}',
                  style: AppTextStyles.caption,
                ),
              ),
              ActionChip(
                label: const Text('Изменить параметры'),
                labelStyle: AppTextStyles.caption
                    .copyWith(color: AppColors.textPrimary),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          if (overBudget > 0) ...[
            const SizedBox(height: AppSizes.s),
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                  const SizedBox(width: AppSizes.m),
                  Expanded(
                    child: Text(
                      'Обязательная экипировка дороже бюджета на '
                      '${Formatters.price(overBudget)}. Дополнительные товары '
                      'не добавлены.',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSizes.l),
          const Text('Обязательные', style: AppTextStyles.sectionTitle),
          const Text(
            'Для вашего уровня и вида спорта рекомендуется:',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSizes.s),
          for (final RecommendedProduct item in mandatory)
            _cardFor(item, cart),
          if (optional.isNotEmpty) ...[
            const SizedBox(height: AppSizes.l),
            const Text('Рекомендации', style: AppTextStyles.sectionTitle),
            const Text(
              'Что ещё пригодится с учётом стажа и бюджета:',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSizes.s),
            for (final RecommendedProduct item in optional)
              _cardFor(item, cart),
          ],
          const SizedBox(height: AppSizes.m),
          Row(
            children: [
              const Expanded(
                child: Text('Итого за подборку', style: AppTextStyles.body),
              ),
              Text(Formatters.price(state.totalPrice), style: AppTextStyles.priceLarge),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardFor(RecommendedProduct item, CartState cart) {
    final bool inCart = cart.containsProduct(item.product.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.s),
      child: RecommendationCard(
        item: item,
        isInCart: inCart,
        onTap: () => Navigator.of(context)
            .pushNamed(AppRoutes.product, arguments: item.product.id),
        onAdd: () {
          if (inCart) {
            AppMessages.showInfo(context, 'Товар уже в корзине');
          } else {
            _addOne(item);
          }
        },
      ),
    );
  }
}
