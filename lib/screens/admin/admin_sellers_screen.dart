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
import '../../widgets/warning_sheet.dart';

/// Вкладка администратора «Продавцы»: магазины, их товары и нарушения;
/// предупреждение магазину целиком (не по конкретному товару).
class AdminSellersScreen extends StatefulWidget {
  const AdminSellersScreen({super.key});

  @override
  State<AdminSellersScreen> createState() => _AdminSellersScreenState();
}

class _AdminSellersScreenState extends State<AdminSellersScreen> {
  late Future<List<SellerSummary>> _future = _load();

  Future<List<SellerSummary>> _load() => context.read<ModerationRepository>().sellers();

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
    setState(() => _future = _load());
  }

  Future<void> _history(SellerSummary seller) async {
    final List<SellerWarning> warnings =
        await context.read<ModerationRepository>().warningsFor(seller.userId);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        shrinkWrap: true,
        children: [
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
    return FutureBuilder<List<SellerSummary>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<SellerSummary> sellers = snapshot.data ?? const [];
        if (sellers.isEmpty) {
          return const EmptyState(
            icon: Icons.groups_outlined,
            title: 'Продавцов пока нет',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          itemCount: sellers.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppSizes.s),
          itemBuilder: (context, index) {
            final SellerSummary seller = sellers[index];
            return AppCard(
              onTap: () => _history(seller),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storefront_outlined),
                      const SizedBox(width: AppSizes.s),
                      Expanded(
                        child: Text(
                          seller.shopName,
                          style: AppTextStyles.sectionTitle,
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _warn(seller),
                      icon: const Icon(Icons.report_outlined, size: 18),
                      label: const Text('Предупредить магазин'),
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
