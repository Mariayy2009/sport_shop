import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../data/repositories/preferences_repository.dart';
import '../../models/shopping_preferences.dart';
import '../../models/user_sizes.dart';
import '../../services/preferences/style_catalog.dart';
import '../../state/auth_state.dart';
import '../../state/profile_state.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/guest_prompt.dart';

/// Анкета для подбора: любимые цвета, позиция в своём виде спорта,
/// материал. По ней работает «Подбор по анкете», и её учитывает
/// ИИ-помощник.
class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  ShoppingPreferences _preferences = const ShoppingPreferences();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final int? userId = context.read<AuthState>().currentUser?.id;
    if (userId != null) {
      _preferences = await context.read<PreferencesRepository>().read(userId);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    final int? userId = context.read<AuthState>().currentUser?.id;
    if (userId == null) return;
    final NavigatorState navigator = Navigator.of(context);
    setState(() => _isSaving = true);
    await context.read<PreferencesRepository>().save(userId, _preferences);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (_preferences.isEmpty) {
      AppMessages.showInfo(context, 'Анкета сохранена');
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed(AppRoutes.preferenceResults);
  }

  void _toggleColor(String key) {
    final Set<String> colors = {..._preferences.colors};
    colors.contains(key) ? colors.remove(key) : colors.add(key);
    setState(() => _preferences = _preferences.copyWith(colors: colors));
  }

  void _toggleMaterial(String key) {
    final Set<String> materials = {..._preferences.materials};
    materials.contains(key) ? materials.remove(key) : materials.add(key);
    setState(() => _preferences = _preferences.copyWith(materials: materials));
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoggedIn = context.watch<AuthState>().isLoggedIn;
    final UserSizes? sizes = context.watch<ProfileState>().sizes;
    final String? sportName = sizes?.sportName;
    final List<SportPosition> positions = StyleCatalog.positionsFor(sportName);

    return AppScaffold(
      title: 'Анкета для подбора',
      navTab: MainTab.profile,
      bottomAction: isLoggedIn && !_isLoading
          ? CustomButton(
              text: 'Сохранить и подобрать',
              isLoading: _isSaving,
              onPressed: _save,
            )
          : null,
      body: !isLoggedIn
          ? const GuestPrompt(
              title: 'Анкета для подбора',
              message: 'Войдите, чтобы мы подбирали товары под ваш вкус',
              icon: Icons.tune,
            )
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(AppSizes.screenPadding),
                  children: [
                    const Text(
                      'Расскажи о себе — подберём вещи для твоей позиции, '
                      'в любимых цветах и из подходящей ткани.',
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: AppSizes.l),
                    const Text('Любимые цвета', style: AppTextStyles.sectionTitle),
                    const SizedBox(height: AppSizes.xxs),
                    const Text('Можно выбрать несколько', style: AppTextStyles.caption),
                    const SizedBox(height: AppSizes.m),
                    Wrap(
                      spacing: AppSizes.m,
                      runSpacing: AppSizes.m,
                      children: [
                        for (final ColorChoice color in StyleCatalog.colors)
                          _ColorDot(
                            color: color,
                            selected: _preferences.colors.contains(color.key),
                            onTap: () => _toggleColor(color.key),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.xl),
                    Text(
                      sportName == null ? 'Позиция в игре' : 'Позиция: $sportName',
                      style: AppTextStyles.sectionTitle,
                    ),
                    const SizedBox(height: AppSizes.s),
                    if (sportName == null)
                      _SportMissing(
                        onTap: () => Navigator.of(context).pushNamed(AppRoutes.editProfile),
                      )
                    else
                      for (final SportPosition position in positions)
                        _OptionCard(
                          title: position.title,
                          subtitle: position.about,
                          selected: _preferences.position == position.key,
                          onTap: () => setState(() {
                            _preferences = _preferences.position == position.key
                                ? _preferences.copyWith(clearPosition: true)
                                : _preferences.copyWith(position: position.key);
                          }),
                        ),
                    const SizedBox(height: AppSizes.l),
                    const Text('Материал', style: AppTextStyles.sectionTitle),
                    const SizedBox(height: AppSizes.s),
                    for (final MaterialChoice material in StyleCatalog.materials)
                      _OptionCard(
                        title: material.name,
                        subtitle: material.hint,
                        selected: _preferences.materials.contains(material.key),
                        onTap: () => _toggleMaterial(material.key),
                      ),
                  ],
                ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final ColorChoice color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool light = color.sample.computeLuminance() > 0.6;
    return Semantics(
      button: true,
      selected: selected,
      label: color.name,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.sample,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.black : AppColors.border,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check,
                        color: light ? AppColors.black : AppColors.white)
                    : null,
              ),
              const SizedBox(height: AppSizes.xxs),
              Text(
                color.name,
                style: AppTextStyles.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(AppSizes.radiusM);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.s),
      child: Material(
        color: selected ? AppColors.accentSoft : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.m),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSizes.xxs),
                      Text(subtitle, style: AppTextStyles.bodySecondary),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? AppColors.accent : AppColors.textHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SportMissing extends StatelessWidget {
  const _SportMissing({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Укажи вид спорта в профиле — появятся позиции: '
            'либеро, вратарь, марафон и другие',
            style: AppTextStyles.bodySecondary,
          ),
        ),
        TextButton(onPressed: onTap, child: const Text('Указать')),
      ],
    );
  }
}
