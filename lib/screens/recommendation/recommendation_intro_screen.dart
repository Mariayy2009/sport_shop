import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../models/user.dart';
import '../../state/auth_state.dart';
import '../../state/profile_state.dart';
import '../../state/recommendation_state.dart';

/// Приветствие AI-подбора (фрейм Figma «ии1»).
/// Имя берётся из текущего пользователя. Текст нейтральный по роду,
/// так как пол в базе не хранится.
class RecommendationIntroScreen extends StatelessWidget {
  const RecommendationIntroScreen({super.key, required this.onDecline});

  final VoidCallback onDecline;

  void _start(BuildContext context) {
    context
        .read<RecommendationState>()
        .startQuiz(context.read<ProfileState>().sizes);
    Navigator.of(context).pushNamed(AppRoutes.recommendationQuiz);
  }

  void _decline(BuildContext context) {
    AppMessages.showInfo(
      context,
      'Хорошо! Вернуться к подбору можно в любой момент во вкладке AI',
    );
    onDecline();
  }

  @override
  Widget build(BuildContext context) {
    final User? user = context.watch<AuthState>().currentUser;
    final bool hasResults = context.watch<RecommendationState>().hasResults;
    final String name = user?.greetingName ?? 'друг';

    return ListView(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        const SizedBox(height: AppSizes.l),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Container(
              padding: const EdgeInsets.all(AppSizes.l),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppSizes.radiusL),
                  topRight: Radius.circular(AppSizes.radiusL),
                  bottomRight: Radius.circular(AppSizes.radiusL),
                ),
              ),
              child: Text(
                'Привет, $name!\n'
                'Если хочешь, давай подберём тебе спортивную экипировку '
                'под твой вид спорта, уровень, размеры и бюджет.',
                style: AppTextStyles.body.copyWith(
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 120),
        Align(
          alignment: Alignment.centerRight,
          child: _ChatOptionButton(
            icon: Icons.check_circle_outline,
            text: 'Да, давай.',
            isPrimary: true,
            onTap: () => _start(context),
          ),
        ),
        const SizedBox(height: AppSizes.m),
        Align(
          alignment: Alignment.centerRight,
          child: _ChatOptionButton(
            icon: Icons.cancel_outlined,
            text: 'Не сейчас.',
            isPrimary: false,
            onTap: () => _decline(context),
          ),
        ),
        if (hasResults) ...[
          const SizedBox(height: AppSizes.xl),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context)
                  .pushNamed(AppRoutes.recommendationResult),
              child: const Text('Посмотреть прошлую подборку'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Кнопка-ответ в стиле сообщения чата.
class _ChatOptionButton extends StatelessWidget {
  const _ChatOptionButton({
    required this.icon,
    required this.text,
    required this.isPrimary,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color foreground =
        isPrimary ? AppColors.textOnDark : AppColors.textPrimary;
    const BorderRadius radius = BorderRadius.only(
      topLeft: Radius.circular(AppSizes.radiusL),
      topRight: Radius.circular(AppSizes.radiusL),
      bottomLeft: Radius.circular(AppSizes.radiusL),
    );
    return Material(
      color: isPrimary ? AppColors.black : AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.l,
            vertical: AppSizes.m,
          ),
          child: Row(
            children: [
              Icon(icon, color: foreground, size: 28),
              const SizedBox(width: AppSizes.m),
              Text(
                text,
                style: AppTextStyles.sectionTitle.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
