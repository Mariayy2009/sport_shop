import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../core/utils/formatters.dart';
import '../../models/user.dart';
import '../../models/user_sizes.dart';
import '../../state/auth_state.dart';
import '../../state/profile_state.dart';
import '../../widgets/app_card.dart';

/// Профиль (фрейм Figma «профиль»): аватар, имя, телефон,
/// параметры из user_sizes и меню действий.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onOpenAi});

  final VoidCallback onOpenAi;

  Future<void> _logout(BuildContext context) async {
    final bool confirmed = await AppMessages.showConfirmDialog(
      context,
      title: AppStrings.logoutTitle,
      message: AppStrings.logoutMessage,
      confirmText: AppStrings.logoutConfirm,
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await context.read<AuthState>().logout();
    if (!context.mounted) return;
    AppMessages.showInfo(context, AppStrings.logoutDone);
  }

  void _openEdit(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.editProfile);

  @override
  Widget build(BuildContext context) {
    final AuthState authState = context.watch<AuthState>();
    final User? user = authState.currentUser;
    final ProfileState profileState = context.watch<ProfileState>();
    if (user == null) return const SizedBox.shrink();
    final UserSizes? sizes = profileState.sizes;

    return RefreshIndicator(
      onRefresh: profileState.load,
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        children: [
          const SizedBox(height: AppSizes.s),
          Center(
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent, width: 3),
              ),
              alignment: Alignment.center,
              child: Text(
                user.greetingName.characters.first.toUpperCase(),
                style: AppTextStyles.screenTitle.copyWith(fontSize: 44),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.m),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  user.fullName,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.sectionTitle.copyWith(fontSize: 20),
                ),
              ),
              IconButton(
                tooltip: 'Редактировать профиль',
                onPressed: () => _openEdit(context),
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
            ],
          ),
          Text(
            user.phone ?? 'Телефон не указан',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary,
          ),
          Text(user.email, textAlign: TextAlign.center, style: AppTextStyles.caption),
          const SizedBox(height: AppSizes.l),
          if (profileState.isLoading && sizes == null)
            const Center(child: CircularProgressIndicator())
          else if (sizes == null || !sizes.isComplete)
            _FillProfileBanner(onTap: () => _openEdit(context)),
          if (sizes != null) ...[
            if (!sizes.isComplete) const SizedBox(height: AppSizes.m),
            _ParametersCard(sizes: sizes),
          ],
          const SizedBox(height: AppSizes.l),
          _MenuItem(
            icon: Icons.receipt_long_outlined,
            title: 'История заказов',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.orderHistory),
          ),
          _MenuItem(
            icon: Icons.favorite_border,
            title: 'Избранное',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.favorites),
          ),
          _MenuItem(
            icon: Icons.auto_awesome_outlined,
            title: 'ИИ-помощник',
            onTap: onOpenAi,
          ),
          _MenuItem(
            icon: Icons.inventory_2_outlined,
            title: 'Мой комплект',
            onTap: () => Navigator.of(context)
                .pushNamed(AppRoutes.kits, arguments: sizes?.sportId),
          ),
          _MenuItem(
            icon: Icons.checkroom,
            title: 'Примерочная',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.fittingRoom),
          ),
          _MenuItem(
            icon: Icons.edit_outlined,
            title: 'Редактировать профиль',
            onTap: () => _openEdit(context),
          ),
          if (authState.isAdmin)
            _MenuItem(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Панель администратора',
              onTap: () => AppMessages.showInfoDialog(
                context,
                title: 'Панель администратора',
                message: 'Управление товарами, категориями, видами спорта, '
                    'правилами рекомендаций и заказами будет доступно '
                    'в следующей версии приложения.',
              ),
            ),
          _MenuItem(
            icon: Icons.logout,
            title: AppStrings.logoutConfirm,
            isDestructive: true,
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}

class _ParametersCard extends StatelessWidget {
  const _ParametersCard({required this.sizes});

  final UserSizes sizes;

  @override
  Widget build(BuildContext context) {
    String orDash(Object? value, [String suffix = '']) =>
        value == null ? '—' : '$value$suffix';
    final int? experience = sizes.experienceYears;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.l,
        vertical: AppSizes.m,
      ),
      child: Column(
        children: [
          _ParamRow(label: 'Рост', value: orDash(sizes.height, ' см')),
          _ParamRow(label: 'Вес', value: orDash(sizes.weight, ' кг')),
          _ParamRow(label: 'Размер одежды', value: orDash(sizes.clothingSize)),
          _ParamRow(label: 'Размер обуви', value: orDash(sizes.shoeSize)),
          _ParamRow(label: 'Спорт', value: orDash(sizes.sportName)),
          _ParamRow(
            label: 'Опыт',
            value: experience == null ? '—' : Formatters.years(experience),
          ),
          _ParamRow(label: 'Уровень', value: sizes.level.label),
        ],
      ),
    );
  }
}

class _ParamRow extends StatelessWidget {
  const _ParamRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xxs + 1),
      child: Row(
        children: [
          const Text('•  ', style: AppTextStyles.body),
          Expanded(child: Text('$label:', style: AppTextStyles.body)),
          Text(
            value,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _FillProfileBanner extends StatelessWidget {
  const _FillProfileBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: const Row(
        children: [
          Icon(Icons.straighten, color: AppColors.warning),
          SizedBox(width: AppSizes.m),
          Expanded(
            child: Text(
              'Заполните рост, вес, размеры и стаж — так подбор '
              'экипировки будет точнее',
              style: AppTextStyles.bodySecondary,
            ),
          ),
          Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final Color color = isDestructive ? AppColors.error : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.s),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: AppSizes.m),
            Expanded(
              child: Text(title, style: AppTextStyles.body.copyWith(color: color)),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}
