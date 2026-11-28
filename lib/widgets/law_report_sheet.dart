import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/app_messages.dart';
import '../data/repositories/moderation_repository.dart';
import '../state/auth_state.dart';

/// Материалы для правоохранительных органов: данные продавца, товары
/// с находками автопроверки, заказы, предупреждения. Приложение само
/// ничего никуда не отправляет — администратор копирует текст и
/// передаёт его официально (заявление в полицию или ответ на запрос),
/// а факт подготовки записывается в журнал.
class LawReportSheet extends StatefulWidget {
  const LawReportSheet({super.key, required this.sellerId, this.productId});

  final int sellerId;
  final int? productId;

  static Future<void> show(BuildContext context, {required int sellerId, int? productId}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => LawReportSheet(sellerId: sellerId, productId: productId),
      );

  @override
  State<LawReportSheet> createState() => _LawReportSheetState();
}

class _LawReportSheetState extends State<LawReportSheet> {
  late final Future<String> _report = context
      .read<ModerationRepository>()
      .buildLawReport(sellerId: widget.sellerId, productId: widget.productId);

  Future<void> _save(String text) async {
    final ModerationRepository moderation = context.read<ModerationRepository>();
    final int? adminId = context.read<AuthState>().currentUser?.id;
    await Clipboard.setData(ClipboardData(text: text));
    await moderation.saveLawReport(
      sellerId: widget.sellerId,
      productId: widget.productId,
      adminId: adminId,
      text: text,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    AppMessages.showSuccess(
      context,
      'Текст скопирован и записан в журнал. Передайте его в полицию вместе с заявлением',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: FutureBuilder<String>(
        future: _report,
        builder: (context, snapshot) {
          final String? text = snapshot.data;
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenPadding, 0, AppSizes.screenPadding, AppSizes.l,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Материалы для полиции', style: AppTextStyles.sectionTitle),
                const SizedBox(height: AppSizes.xs),
                const Text(
                  'Приложение не отправляет данные само. Проверьте текст, скопируйте '
                  'его и передайте официально: с заявлением в полицию (102) или в ответ '
                  'на запрос правоохранительных органов.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppSizes.s),
                Expanded(
                  child: text == null
                      ? Center(
                          child: snapshot.hasError
                              ? Text('${snapshot.error}', style: AppTextStyles.bodySecondary)
                              : const CircularProgressIndicator(),
                        )
                      : Container(
                          padding: const EdgeInsets.all(AppSizes.s),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(AppSizes.radiusM),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(text, style: AppTextStyles.caption.copyWith(height: 1.4)),
                          ),
                        ),
                ),
                const SizedBox(height: AppSizes.s),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.black),
                  onPressed: text == null ? null : () => _save(text),
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Скопировать и записать в журнал'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
