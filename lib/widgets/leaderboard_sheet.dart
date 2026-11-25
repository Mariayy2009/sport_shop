import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import '../data/repositories/game_repository.dart';
import '../services/games/ball_game.dart';

/// Таблица рекордов игры с мячом: лучший результат каждого игрока
/// в выбранном режиме. Свой результат выделен.
class LeaderboardSheet extends StatelessWidget {
  const LeaderboardSheet({
    super.key,
    required this.repository,
    required this.mode,
    required this.userId,
  });

  final GameRepository repository;
  final BallGameMode mode;
  final int userId;

  static Future<void> show(
    BuildContext context,
    GameRepository repository,
    BallGameMode mode,
    int userId,
  ) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) =>
            LeaderboardSheet(repository: repository, mode: mode, userId: userId),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding, 0, AppSizes.screenPadding, AppSizes.l,
        ),
        child: FutureBuilder<List<LeaderboardEntry>>(
          future: repository.leaderboard(mode.name),
          builder: (context, snapshot) {
            final List<LeaderboardEntry>? entries = snapshot.data;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Рекорды: ${mode.title}', style: AppTextStyles.sectionTitle),
                const SizedBox(height: AppSizes.m),
                if (entries == null)
                  const Center(child: CircularProgressIndicator())
                else if (entries.isEmpty)
                  const Text(
                    'Пока никто не играл в этом режиме — стань первым!',
                    style: AppTextStyles.bodySecondary,
                  )
                else
                  for (final (int i, LeaderboardEntry entry) in entries.indexed)
                    Container(
                      margin: const EdgeInsets.only(bottom: AppSizes.xs),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.m,
                        vertical: AppSizes.s,
                      ),
                      decoration: BoxDecoration(
                        color: entry.userId == userId
                            ? AppColors.logoRed.withValues(alpha: 0.08)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: i < 3
                                ? Icon(
                                    Icons.emoji_events,
                                    size: 20,
                                    color: const [
                                      Color(0xFFD4A017),
                                      Color(0xFF9EA3A8),
                                      Color(0xFFB0703C),
                                    ][i],
                                  )
                                : Text('${i + 1}', style: AppTextStyles.bodySecondary),
                          ),
                          Expanded(
                            child: Text(
                              entry.userId == userId ? '${entry.name} (вы)' : entry.name,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: entry.userId == userId
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          Text('${entry.score}', style: AppTextStyles.price),
                        ],
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}
