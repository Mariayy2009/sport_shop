import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/feedback_repository.dart';
import '../../data/repositories/moderation_repository.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../state/product_state.dart';
import '../../models/product_filter.dart';
import '../../models/question.dart';
import '../../state/auth_state.dart';
import '../../state/order_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/order_manage_card.dart';
import '../../widgets/warning_sheet.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_image.dart';
import '../../widgets/text_input_sheet.dart';

/// Панель администратора: товары, заказы и вопросы покупателей.
/// Доступна только пользователю с ролью admin.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key, this.embedded = false});

  /// Внутри нижней вкладки «Модерация» — без своей шапки и навигации.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthState>().isAdmin) {
      return const AppScaffold(
        title: 'Панель администратора',
        navTab: MainTab.profile,
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'Нет доступа',
          message: 'Раздел доступен только администратору магазина',
        ),
      );
    }
    final Widget content = Column(
      children: [
        Material(
          color: AppColors.surface,
          child: TabBar(
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.accent,
            labelStyle:
                AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Товары'),
              Tab(text: 'Заказы'),
              Tab(text: 'Вопросы'),
            ],
          ),
        ),
        const Expanded(
          child: TabBarView(
            children: [_ProductsTab(), _OrdersTab(), _QuestionsTab()],
          ),
        ),
      ],
    );
    return DefaultTabController(
      length: 3,
      child: embedded
          ? content
          : AppScaffold(
              title: 'Панель администратора',
              navTab: MainTab.profile,
              body: content,
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// Товары
// -----------------------------------------------------------------------------

class _ProductsTab extends StatefulWidget {
  const _ProductsTab();

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Product>> _future = _load();
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  // Администратор видит и снятые с продажи товары.
  Future<List<Product>> _load() => context
      .read<ProductRepository>()
      .getProducts(const ProductFilter(includeBlocked: true));

  void _reload() => setState(() => _future = _load());

  Future<void> _block(Product product) async {
    final ModerationRepository moderation =
        context.read<ModerationRepository>();
    final (WarningReason, String?)? result = await WarningSheet.show(
      context,
      title: 'Снять «${product.name}» с продажи',
      buttonText: 'Снять с продажи',
    );
    if (result == null) return;
    final ProductState catalog = context.read<ProductState>();
    await moderation.blockProduct(product, result.$1, text: result.$2);
    if (!mounted) return;
    AppMessages.showSuccess(
      context,
      product.sellerId == null
          ? 'Товар снят с продажи. Из каталога покупателей он пропадёт '
              'в течение минуты'
          : 'Товар снят, продавец получил предупреждение. Из каталога '
              'покупателей он пропадёт в течение минуты',
    );
    _reload();
    // Каталог «Товары» обновляем сразу, не дожидаясь перезапуска.
    unawaited(catalog.loadProducts());
  }

  Future<void> _unblock(Product product) async {
    final ProductState catalog = context.read<ProductState>();
    await context.read<ModerationRepository>().unblockProduct(product.id!);
    if (!mounted) return;
    AppMessages.showSuccess(
      context,
      'Товар снова в продаже — в каталоге появится в течение минуты',
    );
    _reload();
    unawaited(catalog.loadProducts());
  }

  Future<void> _warn(Product product) async {
    final ModerationRepository moderation =
        context.read<ModerationRepository>();
    final (WarningReason, String?)? result = await WarningSheet.show(
      context,
      title: 'Предупреждение продавцу «${product.sellerName}»',
      buttonText: 'Отправить предупреждение',
    );
    if (result == null) return;
    await moderation.warnSeller(
      sellerId: product.sellerId!,
      productId: product.id,
      reason: result.$1,
      text: result.$2,
    );
    if (!mounted) return;
    AppMessages.showSuccess(context, 'Предупреждение отправлено продавцу');
  }

  Future<void> _edit(Product? product) async {
    final Object? changed = await Navigator.of(context)
        .pushNamed(AppRoutes.adminProduct, arguments: product);
    if (changed == true && mounted) setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<Product>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final String query = _query.toLowerCase();
        final List<Product> products = (snapshot.data ?? const [])
            .where((product) => product.name.toLowerCase().contains(query))
            .toList();
        return ListView(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value.trim()),
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      hintText: 'Найти товар',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusPill),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.s),
                IconButton.filled(
                  tooltip: 'Добавить товар',
                  style: IconButton.styleFrom(backgroundColor: AppColors.black),
                  onPressed: () => _edit(null),
                  icon: const Icon(Icons.add, color: AppColors.white),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.m),
            Text(
              'Товаров: ${products.length}',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSizes.s),
            for (final Product product in products)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.s),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSizes.s),
                  onTap: () => _edit(product),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          ProductImage(
                            imageUrl: product.imageUrl,
                            width: 52,
                            height: 52,
                            borderRadius: AppSizes.radiusS,
                          ),
                          const SizedBox(width: AppSizes.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.body
                                      .copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${Formatters.price(product.price)} · '
                                  'Продавец: ${product.sellerTitle}',
                                  style: AppTextStyles.caption,
                                ),
                                if (product.isBlocked)
                                  Text(
                                    'Снят с продажи: ${product.blockReason ?? ''}',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            product.isAvailable
                                ? '${product.stock} шт.'
                                : 'Нет',
                            style: AppTextStyles.bodySecondary.copyWith(
                              fontWeight: FontWeight.w600,
                              color: product.stock == 0
                                  ? AppColors.error
                                  : product.stock <= 5
                                      ? AppColors.statusInTransitText
                                      : AppColors.success,
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      // Модерация — сразу видна, без скрытых меню.
                      Wrap(
                        spacing: AppSizes.xs,
                        children: [
                          TextButton.icon(
                            onPressed: () => product.isBlocked
                                ? _unblock(product)
                                : _block(product),
                            icon: Icon(
                              product.isBlocked ? Icons.undo : Icons.block,
                              size: 18,
                              color: product.isBlocked
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                            label: Text(
                              product.isBlocked
                                  ? 'Вернуть в продажу'
                                  : 'Снять с продажи',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: product.isBlocked
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                          ),
                          if (product.sellerId != null)
                            TextButton.icon(
                              onPressed: () => _warn(product),
                              icon: const Icon(Icons.report_outlined, size: 18),
                              label: Text(
                                'Предупредить продавца',
                                style: AppTextStyles.caption
                                    .copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Заказы
// -----------------------------------------------------------------------------

class _OrdersTab extends StatefulWidget {
  const _OrdersTab();

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Order>> _future = _load();

  @override
  bool get wantKeepAlive => true;

  Future<List<Order>> _load() => context.read<OrderRepository>().getAllOrders();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<Order>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<Order> orders = snapshot.data ?? const [];
        if (orders.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Заказов пока нет',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          itemCount: orders.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSizes.s),
          itemBuilder: (context, index) => OrderManageCard(
            order: orders[index],
            onChanged: () async {
              // Если это заказ самого администратора — обновим и его историю.
              await context.read<OrderState>().load();
              if (mounted) setState(() => _future = _load());
            },
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Вопросы
// -----------------------------------------------------------------------------

class _QuestionsTab extends StatefulWidget {
  const _QuestionsTab();

  @override
  State<_QuestionsTab> createState() => _QuestionsTabState();
}

class _QuestionsTabState extends State<_QuestionsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Question>> _future = _load();

  @override
  bool get wantKeepAlive => true;

  Future<List<Question>> _load() =>
      context.read<FeedbackRepository>().getAllQuestions();

  Future<void> _answer(Question question) async {
    final FeedbackRepository repository = context.read<FeedbackRepository>();
    final String? text = await TextInputSheet.show(
      context,
      title: 'Ответ магазина',
      subtitle: question.text,
      hint: 'Ответ увидят все покупатели',
      buttonText: 'Опубликовать ответ',
      maxLength: 500,
      initialText: question.answer ?? '',
    );
    if (text == null) return;
    await repository.answerQuestion(question.id!, text);
    if (mounted) setState(() => _future = _load());
  }

  Future<void> _delete(Question question) async {
    final FeedbackRepository repository = context.read<FeedbackRepository>();
    final bool confirmed = await AppMessages.showConfirmDialog(
      context,
      title: 'Удалить вопрос?',
      message: 'Вопрос и ответ на него исчезнут из карточки товара',
      confirmText: 'Удалить',
      isDestructive: true,
    );
    if (!confirmed) return;
    await repository.deleteQuestion(question.id!);
    if (mounted) setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<Question>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<Question> questions = snapshot.data ?? const [];
        if (questions.isEmpty) {
          return const EmptyState(
            icon: Icons.help_outline,
            title: 'Вопросов пока нет',
            message: 'Вопросы покупателей о товарах появятся здесь',
          );
        }
        final int waiting =
            questions.where((question) => !question.isAnswered).length;
        return ListView(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          children: [
            Text(
              waiting == 0 ? 'Все вопросы с ответом' : 'Ждут ответа: $waiting',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSizes.s),
            for (final Question question in questions)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.s),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${question.productName ?? 'Товар'} · '
                        '${question.authorName ?? 'Покупатель'} · '
                        '${Formatters.date(question.createdAt)}',
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: AppSizes.xxs),
                      Text(
                        question.text,
                        style: AppTextStyles.body
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (question.isAnswered) ...[
                        const SizedBox(height: AppSizes.xs),
                        Text(question.answer!,
                            style: AppTextStyles.bodySecondary),
                      ],
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => _answer(question),
                            child: Text(
                              question.isAnswered
                                  ? 'Изменить ответ'
                                  : 'Ответить',
                              style: const TextStyle(color: AppColors.accent),
                            ),
                          ),
                          const SizedBox(width: AppSizes.l),
                          TextButton(
                            onPressed: () => _delete(question),
                            child: const Text(
                              'Удалить',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
