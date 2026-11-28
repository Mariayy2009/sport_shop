import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/moderation_repository.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/law_report_sheet.dart';
import '../../widgets/text_input_sheet.dart';
import '../../widgets/warning_sheet.dart';

/// Вкладка администратора «Продавцы»: магазины, их товары и нарушения;
/// предупреждение магазину целиком (не по конкретному товару).
class AdminSellersScreen extends StatefulWidget {
  const AdminSellersScreen({super.key});

  @override
  State<AdminSellersScreen> createState() => _AdminSellersScreenState();
}

class _AdminSellersScreenState extends State<AdminSellersScreen> {
  late Future<(List<SellerSummary>, List<SellerAppeal>)> _future = _load();

  Future<(List<SellerSummary>, List<SellerAppeal>)> _load() async {
    final ModerationRepository moderation = context.read<ModerationRepository>();
    return (await moderation.sellers(), await moderation.pendingAppeals());
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _freeze(SellerSummary seller) async {
    final ModerationRepository moderation = context.read<ModerationRepository>();
    final String? reason = await TextInputSheet.show(
      context,
      title: 'Заморозить «${seller.shopName}»',
      subtitle: 'Товары магазина пропадут из каталога, выставлять новые '
          'будет нельзя. Продавец увидит причину и сможет подать апелляцию',
      hint: 'Причина, например: повторные жалобы на подделки',
      buttonText: 'Заморозить',
      maxLength: 300,
    );
    if (reason == null || reason.trim().isEmpty) return;
    await moderation.freezeSeller(seller.userId, reason.trim());
    if (!mounted) return;
    AppMessages.showSuccess(
      context,
      'Магазин заморожен. Его товары пропадут из каталога в течение минуты',
    );
    _reload();
  }

  Future<void> _delete(SellerSummary seller) async {
    final ModerationRepository moderation = context.read<ModerationRepository>();
    final String? reason = await DeleteSellerSheet.show(context, seller.shopName);
    if (reason == null || !mounted) return;
    // Второе подтверждение — удаление крайняя мера.
    final bool sure = await AppMessages.showConfirmDialog(
      context,
      title: 'Вы уверены, что хотите удалить «${seller.shopName}»?',
      message: 'Магазин закроется, все его товары пропадут из каталога. '
          'Вернуть магазин можно только по апелляции продавца.',
      confirmText: 'Да, удалить',
      isDestructive: true,
    );
    if (!sure) return;
    await moderation.deleteSeller(seller.userId, reason);
    if (!mounted) return;
    AppMessages.showSuccess(context, 'Магазин «${seller.shopName}» удалён');
    _reload();
  }

  Future<void> _restore(SellerSummary seller) async {
    final ModerationRepository moderation = context.read<ModerationRepository>();
    final bool sure = await AppMessages.showConfirmDialog(
      context,
      title: seller.status == SellerStatus.deleted
          ? 'Восстановить «${seller.shopName}»?'
          : 'Разморозить «${seller.shopName}»?',
      message: 'Товары магазина снова появятся в каталоге',
      confirmText: 'Восстановить',
    );
    if (!sure) return;
    await moderation.restoreSeller(seller.userId);
    if (!mounted) return;
    AppMessages.showSuccess(context, 'Магазин снова работает');
    _reload();
  }

  Future<void> _resolve(SellerAppeal appeal, {required bool accept}) async {
    final ModerationRepository moderation = context.read<ModerationRepository>();
    final String? reply = await TextInputSheet.show(
      context,
      title: accept ? 'Принять апелляцию' : 'Отклонить апелляцию',
      subtitle: accept
          ? 'Магазин «${appeal.shopName}» снова заработает'
          : 'Объясните продавцу, почему ограничение остаётся',
      hint: accept
          ? 'Комментарий продавцу, например: нарушения исправлены'
          : 'Причина отказа',
      buttonText: accept ? 'Принять и восстановить' : 'Отклонить',
      maxLength: 300,
    );
    if (reply == null) return;
    if (!accept && reply.trim().isEmpty) {
      if (mounted) AppMessages.showWarning(context, 'Напишите причину отказа');
      return;
    }
    await moderation.resolveAppeal(appeal.id, accept: accept, reply: reply.trim());
    if (!mounted) return;
    AppMessages.showSuccess(
      context,
      accept ? 'Апелляция принята, магазин восстановлен' : 'Апелляция отклонена',
    );
    _reload();
  }

  Future<void> _warn(SellerSummary seller) async {
    final ModerationRepository moderation = context.read<ModerationRepository>();
    final (WarningReason, String?)? result = await WarningSheet.show(
      context,
      title: 'Предупреждение магазину «${seller.shopName}»',
      buttonText: 'Отправить предупреждение',
    );
    if (result == null) return;
    await moderation.warnSeller(
      sellerId: seller.userId,
      reason: result.$1,
      text: result.$2,
    );
    if (!mounted) return;
    AppMessages.showSuccess(context, 'Предупреждение отправлено');
    _reload();
  }

  Future<void> _history(SellerSummary seller) async {
    final ModerationRepository moderation = context.read<ModerationRepository>();
    final List<SellerWarning> warnings = await moderation.warningsFor(seller.userId);
    final SellerLegal legal = await moderation.legalOf(seller.userId);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        shrinkWrap: true,
        children: [
          Text('Данные продавца: ${seller.shopName}', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSizes.xs),
          if (!legal.complete)
            Text(
              'Продавец ещё не заполнил данные и не принял правила — выставлять товары он не может',
              style: AppTextStyles.bodySecondary.copyWith(color: AppColors.error),
            )
          else ...[
            Text('${legal.legalForm}, ${legal.isBin ? 'БИН' : 'ИИН'} ${legal.iin}', style: AppTextStyles.body),
            Text(legal.legalName ?? '', style: AppTextStyles.body),
            Text('${legal.phone} · ${seller.email}', style: AppTextStyles.bodySecondary),
            Text(legal.address ?? '', style: AppTextStyles.bodySecondary),
            Text(
              'Правила (ред. ${legal.rulesVersion}) приняты ${Formatters.date(legal.agreedAt!)}',
              style: AppTextStyles.caption,
            ),
          ],
          const SizedBox(height: AppSizes.m),
          Text('Предупреждения: ${seller.shopName}', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSizes.s),
          if (warnings.isEmpty)
            const Text('Предупреждений не было', style: AppTextStyles.bodySecondary),
          for (final SellerWarning warning in warnings)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.report_gmailerrorred, color: AppColors.error),
              title: Text(warning.reason.label),
              subtitle: Text([
                if (warning.productName != null) warning.productName!,
                if (warning.text != null) warning.text!,
                Formatters.date(warning.createdAt),
              ].join(' · ')),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<SellerSummary>, List<SellerAppeal>)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<SellerSummary> sellers = snapshot.data?.$1 ?? const [];
        final List<SellerAppeal> appeals = snapshot.data?.$2 ?? const [];
        if (sellers.isEmpty) {
          return const EmptyState(
            icon: Icons.groups_outlined,
            title: 'Продавцов пока нет',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          children: [
            if (appeals.isNotEmpty) ...[
              Text('Апелляции (${appeals.length})', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSizes.s),
              for (final SellerAppeal appeal in appeals)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.s),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '«${appeal.shopName ?? 'Продавец'}» · ${Formatters.date(appeal.createdAt)}',
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSizes.xxs),
                        Text(appeal.text, style: AppTextStyles.body),
                        Wrap(
                          spacing: AppSizes.s,
                          children: [
                            TextButton.icon(
                              onPressed: () => _resolve(appeal, accept: true),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Принять'),
                            ),
                            TextButton.icon(
                              onPressed: () => _resolve(appeal, accept: false),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Отклонить'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSizes.m),
              const Text('Магазины', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSizes.s),
            ],
            for (final SellerSummary seller in sellers)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.s),
                child: _SellerCard(
                  seller: seller,
                  onHistory: () => _history(seller),
                  onWarn: () => _warn(seller),
                  onFreeze: () => _freeze(seller),
                  onDelete: () => _delete(seller),
                  onRestore: () => _restore(seller),
                  onLaw: () => LawReportSheet.show(context, sellerId: seller.userId),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({
    required this.seller,
    required this.onHistory,
    required this.onWarn,
    required this.onFreeze,
    required this.onDelete,
    required this.onRestore,
    required this.onLaw,
  });

  final VoidCallback onLaw;
  final SellerSummary seller;
  final VoidCallback onHistory;
  final VoidCallback onWarn;
  final VoidCallback onFreeze;
  final VoidCallback onDelete;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final bool active = seller.status == SellerStatus.active;
    final Color statusColor = switch (seller.status) {
      SellerStatus.active => AppColors.success,
      SellerStatus.frozen => const Color(0xFF2B6CB0),
      SellerStatus.deleted => AppColors.error,
    };
    return AppCard(
      onTap: onHistory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_outlined),
              const SizedBox(width: AppSizes.s),
              Expanded(
                child: Text(seller.shopName, style: AppTextStyles.sectionTitle),
              ),
              Text(
                seller.status.label,
                style: AppTextStyles.caption.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Text(seller.email, style: AppTextStyles.caption),
          const SizedBox(height: AppSizes.xs),
          Text(
            'Товаров: ${seller.products} · снято с продажи: ${seller.blocked} · '
            'предупреждений: ${seller.warnings}',
            style: AppTextStyles.bodySecondary.copyWith(
              color: seller.blocked + seller.warnings > 0
                  ? AppColors.error
                  : AppColors.textSecondary,
            ),
          ),
          if (!active && seller.statusReason != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.xxs),
              child: Text('Причина: ${seller.statusReason}', style: AppTextStyles.caption),
            ),
          if (seller.pendingAppeals > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.xxs),
              child: Text(
                'Ждёт решения апелляция (${seller.pendingAppeals}) — см. выше',
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          if (active)
            Text(
              'При ${ModerationRepository.autoFreezeWarnings} предупреждениях подряд '
              'магазин замораживается автоматически',
              style: AppTextStyles.caption,
            ),
          Wrap(
            spacing: AppSizes.xs,
            children: [
              if (active) ...[
                TextButton.icon(
                  onPressed: onWarn,
                  icon: const Icon(Icons.report_outlined, size: 18),
                  label: const Text('Предупредить'),
                ),
                TextButton.icon(
                  onPressed: onFreeze,
                  icon: const Icon(Icons.ac_unit, size: 18),
                  label: const Text('Заморозить'),
                ),
              ] else
                TextButton.icon(
                  onPressed: onRestore,
                  icon: const Icon(Icons.restore, size: 18),
                  label: Text(seller.status == SellerStatus.deleted
                      ? 'Восстановить'
                      : 'Разморозить'),
                ),
              TextButton.icon(
                onPressed: onLaw,
                icon: const Icon(Icons.local_police_outlined, size: 18),
                label: const Text('Материалы для полиции'),
              ),
              if (seller.status != SellerStatus.deleted)
                TextButton.icon(
                  onPressed: onDelete,
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  icon: const Icon(Icons.delete_forever_outlined, size: 18),
                  label: const Text('Удалить'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Удаление магазина — крайняя мера, поэтому сложнее обычного:
/// обязательная причина и ввод названия магазина для подтверждения.
class DeleteSellerSheet extends StatefulWidget {
  const DeleteSellerSheet({super.key, required this.shopName});

  final String shopName;

  /// Возвращает причину или null, если администратор передумал.
  static Future<String?> show(BuildContext context, String shopName) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => DeleteSellerSheet(shopName: shopName),
      );

  @override
  State<DeleteSellerSheet> createState() => _DeleteSellerSheetState();
}

class _DeleteSellerSheetState extends State<DeleteSellerSheet> {
  static const int minReason = 15;
  final TextEditingController _reason = TextEditingController();
  final TextEditingController _name = TextEditingController();
  WarningReason _kind = WarningReason.fraud;

  @override
  void dispose() {
    _reason.dispose();
    _name.dispose();
    super.dispose();
  }

  bool get _ready =>
      _reason.text.trim().length >= minReason &&
      _name.text.trim().toLowerCase() == widget.shopName.toLowerCase();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        0,
        AppSizes.screenPadding,
        AppSizes.l + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Удалить «${widget.shopName}»', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSizes.xs),
            const Text(
              'Крайняя мера: магазин закроется, все товары пропадут из '
              'каталога. Обычно сначала достаточно заморозки.',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: AppSizes.m),
            Wrap(
              spacing: AppSizes.xs,
              runSpacing: AppSizes.xs,
              children: [
                for (final WarningReason kind in WarningReason.values)
                  ChoiceChip(
                    label: Text(kind.label),
                    selected: kind == _kind,
                    selectedColor: AppColors.black,
                    labelStyle: TextStyle(
                      color: kind == _kind ? AppColors.white : AppColors.textPrimary,
                    ),
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.m),
            TextField(
              controller: _reason,
              maxLines: 3,
              maxLength: 300,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Подробная причина (её увидит продавец)',
                helperText: 'Не короче $minReason символов',
              ),
            ),
            const SizedBox(height: AppSizes.s),
            TextField(
              controller: _name,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Для подтверждения введите: ${widget.shopName}',
              ),
            ),
            const SizedBox(height: AppSizes.l),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: _ready
                    ? () => Navigator.of(context)
                        .pop('${_kind.label}: ${_reason.text.trim()}')
                    : null,
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Удалить магазин'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
