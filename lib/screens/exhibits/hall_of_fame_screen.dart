import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/exhibit_repository.dart';
import '../../models/exhibit.dart';
import '../../state/auth_state.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/exhibit_card.dart';

/// «Зал славы»: экипировка, в которой побеждали.
///
/// Экспонаты университета КНУС и вещи известных спортсменов Казахстана
/// показываются вместе; источник виден по плашке и выбирается фильтром.
class HallOfFameScreen extends StatefulWidget {
  const HallOfFameScreen({super.key});

  @override
  State<HallOfFameScreen> createState() => _HallOfFameScreenState();
}

class _HallOfFameScreenState extends State<HallOfFameScreen> {
  late Future<List<Exhibit>> _future = _load();

  /// null — показывать все источники.
  ExhibitSource? _source;

  Future<List<Exhibit>> _load() => context.read<ExhibitRepository>().getAll();

  Future<void> _add() async {
    final Object? changed =
        await Navigator.of(context).pushNamed(AppRoutes.adminExhibit);
    if (changed == true && mounted) setState(() => _future = _load());
  }

  Future<void> _open(Exhibit exhibit) async {
    await Navigator.of(context).pushNamed(AppRoutes.exhibit, arguments: exhibit.id);
    // Администратор мог изменить или удалить экспонат.
    if (mounted) setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = context.watch<AuthState>().isAdmin;
    return AppScaffold(
      title: 'Зал славы',
      navTab: MainTab.home,
      titleTrailing: isAdmin
          ? IconButton(
              tooltip: 'Добавить экспонат',
              onPressed: _add,
              icon: const Icon(Icons.add),
            )
          : null,
      body: FutureBuilder<List<Exhibit>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<Exhibit> all = snapshot.data ?? const [];
          if (all.isEmpty) {
            return EmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'Экспонаты скоро появятся',
              message: 'Здесь будет экипировка, в которой побеждали: вещи '
                  'из экспозиции КНУС и известных спортсменов Казахстана',
              actionText: isAdmin ? 'Добавить экспонат' : null,
              onAction: isAdmin ? _add : null,
            );
          }
          final List<Exhibit> shown = _source == null
              ? all
              : all.where((exhibit) => exhibit.source == _source).toList();
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Экипировка, в которой побеждали',
                        style: AppTextStyles.screenTitle,
                      ),
                      const SizedBox(height: AppSizes.xs),
                      const Text(
                        'Посмотри на вещи чемпионов, узнай их историю '
                        'и примерь похожую экипировку.',
                        style: AppTextStyles.bodySecondary,
                      ),
                      const SizedBox(height: AppSizes.m),
                      Wrap(
                        spacing: AppSizes.s,
                        children: [
                          _FilterChip(
                            label: 'Все',
                            isSelected: _source == null,
                            onTap: () => setState(() => _source = null),
                          ),
                          for (final ExhibitSource source in ExhibitSource.values)
                            _FilterChip(
                              label: source.label,
                              isSelected: _source == source,
                              onTap: () => setState(() => _source = source),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (shown.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'В этом разделе пока нет экспонатов',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.screenPadding,
                    0,
                    AppSizes.screenPadding,
                    AppSizes.screenPadding,
                  ),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSizes.m,
                      crossAxisSpacing: AppSizes.m,
                      childAspectRatio: 0.68,
                    ),
                    itemCount: shown.length,
                    itemBuilder: (context, index) => ExhibitCard(
                      exhibit: shown[index],
                      onTap: () => _open(shown[index]),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: isSelected,
      showCheckmark: false,
      label: Text(label),
      labelStyle: AppTextStyles.bodySecondary.copyWith(
        color: isSelected ? AppColors.white : AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.black,
      side: BorderSide(color: isSelected ? AppColors.black : AppColors.border),
      shape: const StadiumBorder(),
      onSelected: (_) => onTap(),
    );
  }
}
