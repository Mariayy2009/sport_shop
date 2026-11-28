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
import '../../models/product_filter.dart';
import '../../models/question.dart';
import '../../models/user.dart';
import '../../state/auth_state.dart';
import '../../state/seller_badge_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/order_manage_card.dart';
import '../../widgets/product_image.dart';
import '../../widgets/text_input_sheet.dart';
import '../admin/admin_product_screen.dart';

/// Кабинет продавца: свои товары, заказы с ними («где товар»), вопросы
/// покупателей и предупреждения администратора.
class SellerScreen extends StatelessWidget {
  const SellerScreen({super.key, this.embedded = false});

  /// Внутри нижней вкладки «Кабинет» — без своей шапки и навигации.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final User? user = context.watch<AuthState>().currentUser;
    if (user == null || !user.isSeller) {
      return const AppScaffold(
        title: 'Кабинет продавца',
        navTab: MainTab.profile,
        body: EmptyState(
          icon: Icons.storefront_outlined,
          title: 'Нет доступа',
          message: 'Кабинет доступен продавцам магазина',
        ),
      );
    }
    final SellerBadgeState badges = context.watch<SellerBadgeState>();
    final Widget content = badges.status == SellerStatus.deleted
        // Удалённый магазин: только причина и апелляция.
        ? ListView(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            children: [SellerStatusPanel(sellerId: user.id!, badges: badges)],
          )
        : Column(
            children: [
              if (badges.status == SellerStatus.frozen)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.screenPadding,
                    AppSizes.s,
                    AppSizes.screenPadding,
                    0,
                  ),
                  child: SellerStatusPanel(sellerId: user.id!, badges: badges),
                ),
              Material(
                color: AppColors.surface,
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppColors.textPrimary,
                  indicatorColor: AppColors.black,
                  tabs: [
                    const Tab(text: 'Статистика'),
                    const Tab(text: 'Мои товары'),
                    const Tab(text: 'Заказы'),
                    _BadgeTab(text: 'Вопросы', count: badges.questions),
                    _BadgeTab(text: 'Предупреждения', count: badges.warnings),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _StatsTab(sellerId: user.id!),
                    _ProductsTab(sellerId: user.id!),
                    _OrdersTab(sellerId: user.id!),
                    _QuestionsTab(sellerId: user.id!),
                    _WarningsTab(sellerId: user.id!),
                  ],
                ),
              ),
            ],
          );
    return DefaultTabController(
      length: 5,
      child: embedded
          ? content
          : AppScaffold(
              title: user.shopName ?? 'Кабинет продавца',
              navTab: MainTab.profile,
              body: content,
            ),
    );
  }
}

class _ProductsTab extends StatefulWidget {
  const _ProductsTab({required this.sellerId});

  final int sellerId;

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  late Future<List<Product>> _future = _load();

  Future<List<Product>> _load() =>
      context.read<ProductRepository>().getProducts(
            ProductFilter(sellerId: widget.sellerId, includeBlocked: true),
          );

  Future<void> _edit(Product? product) async {
    final Object? changed =
        await Navigator.of(context).push<Object?>(MaterialPageRoute<Object?>(
      builder: (_) =>
          AdminProductScreen(product: product, sellerId: widget.sellerId),
    ));
    if (changed == true && mounted) setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<Product> products = snapshot.data ?? const [];
        return ListView(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          children: [
            if (!context.watch<SellerBadgeState>().legalComplete)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.m),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Заполните данные продавца',
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSizes.xxs),
                      const Text(
                        'ИИН или БИН, юридический адрес и согласие с правилами площадки. '
                        'Без них выставлять товары нельзя.',
                        style: AppTextStyles.bodySecondary,
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).pushNamed(AppRoutes.sellerVerification),
                        child: const Text('Заполнить'),
                      ),
                    ],
                  ),
                ),
              ),
            OutlinedButton.icon(
              // Замороженный магазин не может выставлять товары.
              onPressed: context.watch<SellerBadgeState>().status == SellerStatus.active &&
                      context.watch<SellerBadgeState>().legalComplete
                  ? () => _edit(null)
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('Выставить товар'),
            ),
            const SizedBox(height: AppSizes.m),
            if (products.isEmpty)
              const Text('Товаров пока нет',
                  style: AppTextStyles.bodySecondary),
            for (final Product product in products)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.s),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSizes.s),
                  onTap: () => _edit(product),
                  child: Row(
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
                              style: AppTextStyles.body
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${Formatters.price(product.price)} · ${product.stock} шт.',
                              style: AppTextStyles.caption,
                            ),
                            if (product.stock <= Product.lowStock &&
                                !product.isBlocked)
                              Text(
                                product.stock == 0
                                    ? 'Закончился — пополните остаток'
                                    : 'Заканчивается: осталось ${product.stock} шт.',
                                style: AppTextStyles.caption.copyWith(
                                  color: const Color(0xFFB45F06),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            if (product.isPendingReview)
                              Text(
                                'На проверке у модератора — в каталоге после проверки',
                                style: AppTextStyles.caption.copyWith(
                                  color: const Color(0xFF2B6CB0),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            if (product.isBlocked)
                              Text(
                                'Снят администратором: ${product.blockReason ?? ''}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
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

/// Сколько продано и на какую сумму: всё время и текущий месяц.
class _StatsTab extends StatefulWidget {
  const _StatsTab({required this.sellerId});

  final int sellerId;

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  late Future<SellerStats> _future =
      context.read<OrderRepository>().sellerStats(widget.sellerId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SellerStats>(
      future: _future,
      builder: (context, snapshot) {
        final SellerStats? stats = snapshot.data;
        if (stats == null) {
          return snapshot.hasError
              ? const EmptyState(
                  icon: Icons.bar_chart,
                  title: 'Статистика недоступна',
                  message: 'Попробуйте открыть вкладку ещё раз',
                )
              : const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: () async {
            final Future<SellerStats> next =
                context.read<OrderRepository>().sellerStats(widget.sellerId);
            setState(() => _future = next);
            await next;
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      title: 'Выручка за месяц',
                      value: Formatters.price(stats.monthRevenue),
                      caption: '${stats.monthSold} шт.',
                    ),
                  ),
                  const SizedBox(width: AppSizes.s),
                  Expanded(
                    child: _StatTile(
                      title: 'Выручка всего',
                      value: Formatters.price(stats.revenue),
                      caption: '${stats.sold} шт. · ${stats.orders} заказов',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.m),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Популярные товары',
                        style: AppTextStyles.sectionTitle),
                    const SizedBox(height: AppSizes.s),
                    if (stats.top.isEmpty)
                      const Text(
                        'Продаж пока нет — они появятся здесь после первых заказов',
                        style: AppTextStyles.bodySecondary,
                      ),
                    for (final (int i, (String name, int sold, double revenue))
                        in stats.top.indexed)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSizes.xxs),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: Text('${i + 1}.',
                                  style: AppTextStyles.bodySecondary),
                            ),
                            Expanded(
                                child: Text(name, style: AppTextStyles.body)),
                            Text(
                              '$sold шт. · ${Formatters.price(revenue)}',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(
      {required this.title, required this.value, required this.caption});

  final String title;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.caption),
          const SizedBox(height: AppSizes.xxs),
          Text(value, style: AppTextStyles.price),
          Text(caption, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _OrdersTab extends StatefulWidget {
  const _OrdersTab({required this.sellerId});

  final int sellerId;

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  late Future<(List<Order>, Set<int>)> _future = _load();

  Future<(List<Order>, Set<int>)> _load() async {
    final List<Order> orders = await context
        .read<OrderRepository>()
        .getOrdersForSeller(widget.sellerId);
    final List<Product> mine =
        await context.read<ProductRepository>().getProducts(
              ProductFilter(sellerId: widget.sellerId, includeBlocked: true),
            );
    return (orders, {for (final Product p in mine) p.id!});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<Order>, Set<int>)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final (List<Order> orders, Set<int> mine) =
            snapshot.data ?? (const <Order>[], const <int>{});
        if (orders.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Заказов пока нет',
            message: 'Здесь появятся заказы с вашими товарами',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          itemCount: orders.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSizes.s),
          itemBuilder: (context, index) => OrderManageCard(
            order: orders[index],
            onlyProductIds: mine,
            onChanged: () => setState(() => _future = _load()),
          ),
        );
      },
    );
  }
}

class _QuestionsTab extends StatefulWidget {
  const _QuestionsTab({required this.sellerId});

  final int sellerId;

  @override
  State<_QuestionsTab> createState() => _QuestionsTabState();
}

class _QuestionsTabState extends State<_QuestionsTab> {
  late Future<List<Question>> _future = _load();

  Future<List<Question>> _load() =>
      context.read<FeedbackRepository>().getQuestionsForSeller(widget.sellerId);

  Future<void> _answer(Question question) async {
    final FeedbackRepository repository = context.read<FeedbackRepository>();
    final String? text = await TextInputSheet.show(
      context,
      title: 'Ответ продавца',
      subtitle: question.text,
      hint: 'Ответ увидят все покупатели',
      buttonText: 'Опубликовать ответ',
      maxLength: 500,
      initialText: question.answer ?? '',
    );
    if (text == null) return;
    await repository.answerQuestion(question.id!, text);
    if (!mounted) return;
    AppMessages.showSuccess(
        context, 'Ответ отправлен — покупатель увидит его в карточке товара');
    unawaited(context.read<SellerBadgeState>().refresh());
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
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
            message: 'Вопросы покупателей о ваших товарах появятся здесь',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          itemCount: questions.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSizes.s),
          itemBuilder: (context, index) {
            final Question question = questions[index];
            return AppCard(
              onTap: () => _answer(question),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${question.productName ?? 'Товар'} · '
                    '${question.authorName ?? 'Покупатель'}',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSizes.xxs),
                  Text(
                    question.text,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    question.answer == null
                        ? 'Нет ответа — нажмите, чтобы ответить'
                        : 'Ваш ответ: ${question.answer}',
                    style: question.answer == null
                        ? AppTextStyles.bodySecondary
                            .copyWith(color: AppColors.error)
                        : AppTextStyles.bodySecondary,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Вкладка с красным кружком-счётчиком: там появилось новое.
class _BadgeTab extends StatelessWidget {
  const _BadgeTab({required this.text, required this.count});

  final String text;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Badge(
        isLabelVisible: count > 0,
        backgroundColor: AppColors.logoRed,
        offset: const Offset(14, -6),
        label: Text('$count'),
        child: Text(text),
      ),
    );
  }
}

class _WarningsTab extends StatefulWidget {
  const _WarningsTab({required this.sellerId});

  final int sellerId;

  @override
  State<_WarningsTab> createState() => _WarningsTabState();
}

class _WarningsTabState extends State<_WarningsTab> {
  late Future<List<SellerWarning>> _future = _load();

  Future<List<SellerWarning>> _load() async {
    final ModerationRepository moderation =
        context.read<ModerationRepository>();
    final List<SellerWarning> warnings =
        await moderation.warningsFor(widget.sellerId);
    // Открыл вкладку — значит, прочитал: кружок пропадает.
    final SellerBadgeState badges = context.read<SellerBadgeState>();
    await moderation.markRead(widget.sellerId);
    await badges.refresh();
    return warnings;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SellerWarning>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<SellerWarning> warnings = snapshot.data ?? const [];
        if (warnings.isEmpty) {
          return const EmptyState(
            icon: Icons.verified_outlined,
            title: 'Предупреждений нет',
            message: 'Администратор пишет сюда, если товар нарушает правила',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          itemCount: warnings.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSizes.s),
          itemBuilder: (context, index) {
            final SellerWarning warning = warnings[index];
            return AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.report_gmailerrorred,
                    color: warning.isRead
                        ? AppColors.textSecondary
                        : AppColors.error,
                  ),
                  const SizedBox(width: AppSizes.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          warning.reason.label,
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (warning.productName != null)
                          Text('Товар: ${warning.productName}',
                              style: AppTextStyles.bodySecondary),
                        if (warning.text != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSizes.xxs),
                            child:
                                Text(warning.text!, style: AppTextStyles.body),
                          ),
                        const SizedBox(height: AppSizes.xxs),
                        Text(Formatters.date(warning.createdAt),
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Плашка замороженного или удалённого магазина: причина, кнопка
/// «Подать апелляцию» и история апелляций с ответами администратора.
class SellerStatusPanel extends StatefulWidget {
  const SellerStatusPanel(
      {super.key, required this.sellerId, required this.badges});

  final int sellerId;
  final SellerBadgeState badges;

  @override
  State<SellerStatusPanel> createState() => _SellerStatusPanelState();
}

class _SellerStatusPanelState extends State<SellerStatusPanel> {
  late Future<List<SellerAppeal>> _future = _load();
  bool _showHistory = false;

  Future<List<SellerAppeal>> _load() =>
      context.read<ModerationRepository>().appealsFor(widget.sellerId);

  Future<void> _appeal() async {
    final ModerationRepository moderation =
        context.read<ModerationRepository>();
    final String? text = await TextInputSheet.show(
      context,
      title: 'Апелляция администратору',
      subtitle:
          'Объясните, что исправили, или спросите, за что ограничили магазин',
      hint: 'Например: удалили спорные товары, прикладываем сертификаты',
      buttonText: 'Отправить апелляцию',
      maxLength: 600,
    );
    if (text == null) return;
    await moderation.submitAppeal(widget.sellerId, text);
    if (!mounted) return;
    AppMessages.showSuccess(
      context,
      'Апелляция отправлена. Администратор ответит в «Уведомлениях»',
    );
    setState(() {
      _future = _load();
      _showHistory = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool deleted = widget.badges.status == SellerStatus.deleted;
    return Container(
      padding: const EdgeInsets.all(AppSizes.m),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: FutureBuilder<List<SellerAppeal>>(
        future: _future,
        builder: (context, snapshot) {
          final List<SellerAppeal> appeals = snapshot.data ?? const [];
          final bool pending = appeals.any((a) => a.isPending);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(deleted ? Icons.block : Icons.ac_unit,
                      color: AppColors.error),
                  const SizedBox(width: AppSizes.s),
                  Expanded(
                    child: Text(
                      deleted
                          ? 'Магазин удалён администратором'
                          : 'Магазин заморожен',
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.xs),
              if (widget.badges.statusReason != null)
                Text('Причина: ${widget.badges.statusReason}',
                    style: AppTextStyles.body),
              Text(
                deleted
                    ? 'Товары не показываются покупателям. Вернуть магазин можно '
                        'только через апелляцию.'
                    : 'Товары скрыты из каталога, выставлять новые нельзя. Заказы '
                        'и вопросы по-прежнему видны.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSizes.s),
              if (pending)
                const Text(
                  'Апелляция на рассмотрении — ответ придёт в «Уведомления»',
                  style: AppTextStyles.bodySecondary,
                )
              else
                OutlinedButton.icon(
                  onPressed: _appeal,
                  icon: const Icon(Icons.gavel_outlined),
                  label: const Text('Подать апелляцию'),
                ),
              if (appeals.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _showHistory = !_showHistory),
                  child: Text(_showHistory
                      ? 'Скрыть апелляции'
                      : 'Мои апелляции (${appeals.length})'),
                ),
              if (_showHistory)
                for (final SellerAppeal appeal in appeals)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSizes.xs),
                    child: Text(
                      '${Formatters.date(appeal.createdAt)} · ${appeal.statusLabel}\n'
                      '«${appeal.text}»'
                      '${appeal.reply == null ? '' : '\nОтвет: ${appeal.reply}'}',
                      style: AppTextStyles.caption,
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
