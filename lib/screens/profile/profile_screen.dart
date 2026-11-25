import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/media_storage.dart';
import '../../state/data_source_state.dart';
import '../../widgets/photo_action_sheet.dart';
import '../../widgets/shop_server_sheet.dart';
import '../../widgets/user_avatar.dart';
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

/// Профиль: аватар (можно сменить), имя, телефон,
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

  /// Аватар: новое фото из камеры или галереи либо удаление.
  Future<void> _changeAvatar(BuildContext context, User user) async {
    final ProfileState profile = context.read<ProfileState>();
    final AuthState auth = context.read<AuthState>();
    final PhotoAction? action = await PhotoActionSheet.show(
      context,
      title: 'Фото профиля',
      canDelete: user.avatarPath != null,
    );
    if (action == null) return;
    try {
      final User? updated = switch (action) {
        PhotoAction.camera => await profile.pickAvatar(user, PhotoSource.camera),
        PhotoAction.gallery => await profile.pickAvatar(user, PhotoSource.gallery),
        PhotoAction.delete => await profile.removeAvatar(user),
      };
      if (updated != null) auth.updateCurrentUser(updated);
    } on Exception catch (error) {
      debugPrint('Не удалось изменить аватар: $error');
      if (context.mounted) {
        AppMessages.showError(
          context,
          'Не удалось получить фото. Проверьте доступ к камере и галерее',
        );
      }
    }
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
            child: Semantics(
              button: true,
              label: 'Изменить аватар',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _changeAvatar(context, user),
                child: Stack(
                  children: [
                    UserAvatar(
                      name: user.greetingName,
                      imagePath: user.avatarPath,
                      size: 112,
                      borderWidth: 3,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.black,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.background, width: 2),
                        ),
                        child: const Icon(
                          Icons.photo_camera_outlined,
                          color: AppColors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
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
            icon: Icons.tune,
            title: 'Анкета для подбора',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.preferences),
          ),
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
          // Покупательские разделы продавцу и администратору не нужны.
          if (!(authState.currentUser?.isSeller ?? false) && !authState.isAdmin) ...[
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
          ],
          _MenuItem(
            icon: Icons.emoji_events_outlined,
            title: 'Зал славы',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.hallOfFame),
          ),
          _MenuItem(
            icon: Icons.checkroom,
            title: 'Примерочная',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.tryOn),
          ),
          _MenuItem(
            icon: Icons.edit_outlined,
            title: 'Редактировать профиль',
            onTap: () => _openEdit(context),
          ),
          // Откуда берётся каталог: с телефона или с сервера магазина.
          // Это настройка для администратора — покупателю и продавцу
          // она ничего не даёт, поэтому им не показывается.
          if (authState.isAdmin)
            _MenuItem(
              icon: Icons.storage_outlined,
              title: context.watch<DataSourceState>().usesServer
                  ? 'Данные: сервер PostgreSQL'
                  : 'Данные: на телефоне',
              onTap: () => ShopServerSheet.show(context),
            ),
          if (authState.currentUser?.isSeller ?? false)
            _MenuItem(
              icon: Icons.storefront_outlined,
              title: 'Кабинет продавца',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.seller),
            ),
          if (authState.isAdmin)
            _MenuItem(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Панель администратора',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.admin),
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
