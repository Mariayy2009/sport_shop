import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/app_messages.dart';
import '../data/repositories/feedback_repository.dart';
import '../models/review.dart';
import '../state/auth_state.dart';
import '../state/product_state.dart';
import 'custom_button.dart';
import 'star_rating.dart';

/// Форма отзыва о купленном товаре: оценка и текст.
/// Возвращает true, если отзыв сохранён или удалён.
class ReviewSheet extends StatefulWidget {
  const ReviewSheet({
    super.key,
    required this.productId,
    required this.productName,
    this.existing,
  });

  final int productId;
  final String productName;
  final Review? existing;

  static Future<bool> show(
    BuildContext context, {
    required int productId,
    required String productName,
    Review? existing,
  }) async {
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusL)),
      ),
      builder: (_) => ReviewSheet(
        productId: productId,
        productName: productName,
        existing: existing,
      ),
    );
    return saved ?? false;
  }

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  late int _rating = widget.existing?.rating ?? 0;
  late final TextEditingController _text =
      TextEditingController(text: widget.existing?.text ?? '');
  bool _isSaving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_rating == 0) {
      AppMessages.showWarning(context, 'Поставьте оценку от 1 до 5');
      return;
    }
    final int? userId = context.read<AuthState>().currentUser?.id;
    if (userId == null) return;
    setState(() => _isSaving = true);
    final String text = _text.text.trim();
    await context.read<FeedbackRepository>().saveReview(Review(
          userId: userId,
          productId: widget.productId,
          rating: _rating,
          text: text.isEmpty ? null : text,
          createdAt: DateTime.now(),
        ));
    await _finish('Спасибо за отзыв!');
  }

  Future<void> _delete() async {
    final int? userId = context.read<AuthState>().currentUser?.id;
    if (userId == null) return;
    setState(() => _isSaving = true);
    await context.read<FeedbackRepository>().deleteReview(userId, widget.productId);
    await _finish('Отзыв удалён');
  }

  /// Рейтинг товара изменился — обновляем каталог и закрываем форму.
  Future<void> _finish(String message) async {
    if (!mounted) return;
    await context.read<ProductState>().loadProducts();
    if (!mounted) return;
    AppMessages.showSuccess(context, message);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSizes.l,
          0,
          AppSizes.l,
          AppSizes.l + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'Ваш отзыв' : 'Изменить отзыв',
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: AppSizes.xxs),
            Text(widget.productName, style: AppTextStyles.bodySecondary),
            const SizedBox(height: AppSizes.m),
            Center(
              child: StarRating(
                rating: _rating,
                size: 36,
                onChanged: (value) => setState(() => _rating = value),
              ),
            ),
            const SizedBox(height: AppSizes.m),
            TextField(
              controller: _text,
              minLines: 3,
              maxLines: 5,
              maxLength: Review.maxTextLength,
              textCapitalization: TextCapitalization.sentences,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: 'Что понравилось, а что нет? Подошёл ли размер?',
                hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.background,
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.s),
            CustomButton(
              text: 'Опубликовать',
              isLoading: _isSaving,
              onPressed: _save,
            ),
            if (widget.existing != null) ...[
              const SizedBox(height: AppSizes.s),
              Center(
                child: TextButton(
                  onPressed: _isSaving ? null : _delete,
                  child: const Text(
                    'Удалить отзыв',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
