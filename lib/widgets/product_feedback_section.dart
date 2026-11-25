import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/routes/app_routes.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/app_messages.dart';
import '../core/utils/formatters.dart';
import '../data/repositories/feedback_repository.dart';
import '../models/product.dart';
import '../models/question.dart';
import '../models/review.dart';
import '../models/user.dart';
import '../state/auth_state.dart';
import 'app_card.dart';
import 'product_image.dart';
import 'review_sheet.dart';
import 'star_rating.dart';
import 'text_input_sheet.dart';
import 'user_avatar.dart';

/// Блок карточки товара «Отзывы | Вопросы».
///
/// Отзыв может оставить только тот, кто получил товар (доставленный
/// заказ). Вопрос — любой вошедший пользователь; отвечает администратор.
class ProductFeedbackSection extends StatefulWidget {
  const ProductFeedbackSection({
    super.key,
    required this.product,
    required this.onRatingChanged,
  });

  final Product product;

  /// Отзыв добавлен или удалён — карточке нужно перечитать рейтинг.
  final VoidCallback onRatingChanged;

  @override
  State<ProductFeedbackSection> createState() => _ProductFeedbackSectionState();
}

class _FeedbackData {
  const _FeedbackData({
    required this.reviews,
    required this.questions,
    required this.canReview,
  });

  final List<Review> reviews;
  final List<Question> questions;

  /// Текущий пользователь получил этот товар.
  final bool canReview;
}

class _ProductFeedbackSectionState extends State<ProductFeedbackSection> {
  late Future<_FeedbackData> _future;
  bool _showQuestions = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_FeedbackData> _load() async {
    final FeedbackRepository repository = context.read<FeedbackRepository>();
    final int? userId = context.read<AuthState>().currentUser?.id;
    final int productId = widget.product.id!;
    return _FeedbackData(
      reviews: await repository.getReviews(productId),
      questions: await repository.getQuestions(productId),
      canReview: userId != null && await repository.hasPurchased(userId, productId),
    );
  }

  void _reload() => setState(() => _future = _load());

  /// Гостю предлагаем войти. Возвращает текущего пользователя или null.
  Future<User?> _requireUser(String action) async {
    final User? user = context.read<AuthState>().currentUser;
    if (user != null) return user;
    final NavigatorState navigator = Navigator.of(context);
    final bool goToLogin = await AppMessages.showConfirmDialog(
      context,
      title: 'Нужен вход',
      message: 'Чтобы $action, войдите в аккаунт или зарегистрируйтесь',
      confirmText: 'Войти',
    );
    if (goToLogin) navigator.pushNamed(AppRoutes.login);
    return null;
  }

  Future<void> _writeReview(_FeedbackData data) async {
    final User? user = await _requireUser('оставить отзыв');
    if (user == null || !mounted) return;
    if (!data.canReview) {
      AppMessages.showInfo(
        context,
        'Отзыв можно оставить после получения заказа с этим товаром',
      );
      return;
    }
    Review? mine;
    for (final Review review in data.reviews) {
      if (review.userId == user.id) mine = review;
    }
    final bool changed = await ReviewSheet.show(
      context,
      productId: widget.product.id!,
      productName: widget.product.name,
      existing: mine,
    );
    if (changed && mounted) {
      _reload();
      widget.onRatingChanged();
    }
  }

  Future<void> _ask() async {
    final User? user = await _requireUser('задать вопрос');
    if (user == null || !mounted) return;
    final FeedbackRepository repository = context.read<FeedbackRepository>();
    final String? text = await TextInputSheet.show(
      context,
      title: 'Вопрос о товаре',
      subtitle: widget.product.name,
      hint: 'Например: подойдёт ли для игры на улице?',
      buttonText: 'Отправить вопрос',
      maxLength: Question.maxTextLength,
    );
    if (text == null) return;
    await repository.askQuestion(Question(
      productId: widget.product.id!,
      userId: user.id!,
      text: text,
      createdAt: DateTime.now(),
    ));
    if (!mounted) return;
    AppMessages.showSuccess(context, 'Вопрос отправлен — магазин ответит здесь');
    setState(() {
      _showQuestions = true;
      _future = _load();
    });
  }

  /// Администратор отвечает прямо в карточке товара.
  Future<void> _answer(Question question) async {
    final FeedbackRepository repository = context.read<FeedbackRepository>();
    final String? text = await TextInputSheet.show(
      context,
      title: widget.product.sellerId == null ? 'Ответ магазина' : 'Ответ продавца',
      subtitle: question.text,
      hint: 'Ответ увидят все покупатели',
      buttonText: 'Опубликовать ответ',
      maxLength: 500,
      initialText: question.answer ?? '',
    );
    if (text == null) return;
    await repository.answerQuestion(question.id!, text);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = context.watch<AuthState>();
    return FutureBuilder<_FeedbackData>(
      future: _future,
      builder: (context, snapshot) {
        final _FeedbackData? data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSizes.l),
            Row(
              children: [
                _Tab(
                  text: 'Отзывы',
                  count: data.reviews.length,
                  isSelected: !_showQuestions,
                  onTap: () => setState(() => _showQuestions = false),
                ),
                const SizedBox(width: AppSizes.s),
                _Tab(
                  text: 'Вопросы',
                  count: data.questions.length,
                  isSelected: _showQuestions,
                  onTap: () => setState(() => _showQuestions = true),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.m),
            if (_showQuestions)
              // Отвечает администратор или продавец этого товара.
              ..._questions(
                data,
                auth.isAdmin ||
                    (auth.currentUser?.isSeller == true &&
                        auth.currentUser?.id == widget.product.sellerId),
              )
            else
              ..._reviews(data, auth.currentUser?.id),
          ],
        );
      },
    );
  }

  List<Widget> _reviews(_FeedbackData data, int? userId) {
    final bool hasMine = data.reviews.any((review) => review.userId == userId);
    return [
      if (data.reviews.isEmpty)
        const _EmptyNote(
          icon: Icons.rate_review_outlined,
          text: 'Отзывов пока нет. Их оставляют покупатели, '
              'которые уже получили товар.',
        ),
      for (final Review review in data.reviews)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.s),
          child: _ReviewCard(review: review, isMine: review.userId == userId),
        ),
      OutlinedButton.icon(
        onPressed: () => _writeReview(data),
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: Text(hasMine ? 'Изменить мой отзыв' : 'Написать отзыв'),
      ),
    ];
  }

  List<Widget> _questions(_FeedbackData data, bool isAdmin) {
    return [
      if (data.questions.isEmpty)
        const _EmptyNote(
          icon: Icons.help_outline,
          text: 'Вопросов пока нет. Спросите о размере, материале '
              'или применении — магазин ответит.',
        ),
      for (final Question question in data.questions)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.s),
          child: _QuestionCard(
            question: question,
            onAnswer: isAdmin ? () => _answer(question) : null,
            answerLabel: widget.product.sellerId == null
                ? 'Ответ магазина'
                : 'Ответ продавца ${widget.product.sellerName ?? ''}'.trim(),
          ),
        ),
      OutlinedButton.icon(
        onPressed: _ask,
        icon: const Icon(Icons.help_outline, size: 18),
        label: const Text('Задать вопрос'),
      ),
    ];
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.text,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String text;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected ? AppColors.black : AppColors.surface,
        shape: StadiumBorder(
          side: BorderSide(color: isSelected ? AppColors.black : AppColors.border),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.l, vertical: AppSizes.s),
            child: Text(
              '$text · $count',
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.m),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: AppSizes.m),
          Expanded(child: Text(text, style: AppTextStyles.bodySecondary)),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.isMine});

  final Review review;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final String name = review.authorName ?? 'Покупатель';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(name: name, imagePath: review.authorAvatarPath, size: 36),
              const SizedBox(width: AppSizes.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMine ? '$name (вы)' : name,
                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (review.verified)
                      Row(
                        children: [
                          const Icon(Icons.verified, size: 14, color: AppColors.success),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Покупатель подтверждён · ${Formatters.date(review.createdAt)}',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.success),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(Formatters.date(review.createdAt), style: AppTextStyles.caption),
                  ],
                ),
              ),
              StarRating(rating: review.rating),
            ],
          ),
          if (review.text != null) ...[
            const SizedBox(height: AppSizes.s),
            Text(review.text!, style: AppTextStyles.body.copyWith(height: 1.4)),
          ],
          if (review.photos.isNotEmpty) ...[
            const SizedBox(height: AppSizes.s),
            Wrap(
              spacing: AppSizes.s,
              children: [
                for (final String photo in review.photos)
                  GestureDetector(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (context) => Dialog(
                        insetPadding: const EdgeInsets.all(AppSizes.l),
                        child: ProductImage(imageUrl: photo, fit: BoxFit.contain),
                      ),
                    ),
                    child: ProductImage(imageUrl: photo, width: 72, height: 72),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.onAnswer,
    this.answerLabel = 'Ответ магазина',
  });

  final Question question;
  final String answerLabel;

  /// Задан только для администратора.
  final VoidCallback? onAnswer;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${question.authorName ?? 'Покупатель'} · '
            '${Formatters.date(question.createdAt)}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSizes.xxs),
          Text(
            question.text,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: AppSizes.s),
          if (question.isAnswered)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.m),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    answerLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.accentDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xxs),
                  Text(question.answer!, style: AppTextStyles.body.copyWith(height: 1.4)),
                ],
              ),
            )
          else
            const Text('Магазин ещё не ответил', style: AppTextStyles.bodySecondary),
          if (onAnswer != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onAnswer,
                child: Text(question.isAnswered ? 'Изменить ответ' : 'Ответить'),
              ),
            ),
        ],
      ),
    );
  }
}
