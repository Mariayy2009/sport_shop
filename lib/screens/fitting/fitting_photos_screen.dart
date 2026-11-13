import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../models/fitting_photos.dart';
import '../../services/media_storage.dart';
import '../../state/auth_state.dart';
import '../../state/fitting_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/guest_prompt.dart';
import '../../widgets/labeled_checkbox.dart';
import '../../widgets/photo_action_sheet.dart';

/// Фото для примерки: лицо и фигура в полный рост.
///
/// Загрузка добровольная и только после согласия. Файлы хранятся
/// в закрытой папке приложения на устройстве; их можно удалить
/// по одному или все сразу.
class FittingPhotosScreen extends StatefulWidget {
  const FittingPhotosScreen({super.key});

  @override
  State<FittingPhotosScreen> createState() => _FittingPhotosScreenState();
}

class _FittingPhotosScreenState extends State<FittingPhotosScreen> {
  bool _consent = false;
  bool _consentError = false;

  Future<void> _change(PhotoKind kind, {required bool hasPhoto}) async {
    final FittingState state = context.read<FittingState>();
    // Согласие нужно один раз — до первой загрузки.
    if (state.photos == null && !_consent) {
      setState(() => _consentError = true);
      AppMessages.showWarning(context, 'Сначала подтвердите согласие на хранение фото');
      return;
    }
    final PhotoAction? action = await PhotoActionSheet.show(
      context,
      title: kind == PhotoKind.face ? 'Фото лица' : 'Фото в полный рост',
      canDelete: hasPhoto,
    );
    if (action == null) return;
    try {
      switch (action) {
        case PhotoAction.camera:
          await state.pick(kind, PhotoSource.camera);
        case PhotoAction.gallery:
          await state.pick(kind, PhotoSource.gallery);
        case PhotoAction.delete:
          await state.remove(kind);
      }
    } on Exception catch (error) {
      debugPrint('Не удалось изменить фото для примерки: $error');
      if (mounted) {
        AppMessages.showError(
          context,
          'Не удалось получить фото. Проверьте доступ к камере и галерее',
        );
      }
    }
  }

  Future<void> _deleteAll() async {
    final FittingState state = context.read<FittingState>();
    final bool confirmed = await AppMessages.showConfirmDialog(
      context,
      title: 'Удалить все фото?',
      message: 'Фото лица и фигуры будут удалены с устройства. '
          'Примерка продолжит работать на манекене.',
      confirmText: 'Удалить',
      isDestructive: true,
    );
    if (!confirmed) return;
    await state.deleteAll();
    if (!mounted) return;
    setState(() => _consent = false);
    AppMessages.showSuccess(context, 'Фото удалены');
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoggedIn = context.watch<AuthState>().isLoggedIn;
    final FittingPhotos? photos = context.watch<FittingState>().photos;

    return AppScaffold(
      title: 'Мои фото для примерки',
      navTab: MainTab.home,
      body: !isLoggedIn
          ? const GuestPrompt(
              title: 'Примерка на своём фото',
              message: 'Войдите, чтобы загрузить фото и увидеть, '
                  'как вещи смотрятся на вас',
              icon: Icons.checkroom,
            )
          : ListView(
              padding: const EdgeInsets.all(AppSizes.screenPadding),
              children: [
                const Text(
                  'Загрузите два фото — и одежда из каталога будет '
                  'примеряться прямо на вас.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: AppSizes.l),
                _PhotoCard(
                  title: 'Фото в полный рост',
                  path: photos?.bodyPath,
                  icon: Icons.accessibility_new,
                  tips: const [
                    'Встаньте прямо, руки слегка в стороны',
                    'В кадре всё тело — от макушки до стоп',
                    'Облегающая одежда, однотонный фон',
                  ],
                  onTap: () => _change(PhotoKind.body, hasPhoto: photos?.hasBody ?? false),
                ),
                const SizedBox(height: AppSizes.m),
                _PhotoCard(
                  title: 'Фото лица',
                  path: photos?.facePath,
                  icon: Icons.face_outlined,
                  tips: const [
                    'Смотрите прямо в камеру',
                    'Лицо занимает большую часть кадра',
                    'Без очков и головного убора',
                  ],
                  onTap: () => _change(PhotoKind.face, hasPhoto: photos?.hasFace ?? false),
                ),
                const SizedBox(height: AppSizes.m),
                const AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.wb_sunny_outlined, color: AppColors.star),
                      SizedBox(width: AppSizes.m),
                      Expanded(
                        child: Text(
                          'Снимайте при хорошем освещении: днём у окна или '
                          'при ярком верхнем свете, без резких теней. '
                          'Так примерка будет точнее.',
                          style: AppTextStyles.bodySecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.m),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock_outline, color: AppColors.accentDark),
                          SizedBox(width: AppSizes.m),
                          Expanded(
                            child: Text(
                              'Ваши фото под защитой',
                              style: AppTextStyles.sectionTitle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.s),
                      const Text(
                        'Фото хранятся только на этом устройстве, в закрытой '
                        'папке приложения. Они никуда не отправляются, не '
                        'видны другим пользователям и не попадают в отзывы. '
                        'Удалить их можно в любой момент.',
                        style: AppTextStyles.bodySecondary,
                      ),
                      if (photos == null) ...[
                        const SizedBox(height: AppSizes.s),
                        LabeledCheckbox(
                          value: _consent,
                          label: 'Согласен(на) на хранение моих фото '
                              'на устройстве для примерки',
                          hasError: _consentError,
                          onChanged: (value) => setState(() {
                            _consent = value;
                            _consentError = false;
                          }),
                        ),
                      ] else ...[
                        const SizedBox(height: AppSizes.s),
                        TextButton.icon(
                          onPressed: _deleteAll,
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.error, size: 18),
                          label: const Text(
                            'Удалить все мои фото',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.title,
    required this.path,
    required this.icon,
    required this.tips,
    required this.onTap,
  });

  final String title;
  final String? path;
  final IconData icon;
  final List<String> tips;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? path = this.path;
    final Widget placeholder =
        Center(child: Icon(icon, size: 40, color: AppColors.accent));
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusS),
            child: Container(
              width: 88,
              height: 116,
              color: AppColors.accentSoft,
              child: path == null
                  ? placeholder
                  : Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => placeholder,
                    ),
            ),
          ),
          const SizedBox(width: AppSizes.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.sectionTitle),
                const SizedBox(height: AppSizes.xs),
                for (final String tip in tips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.xxs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(Icons.check, size: 13, color: AppColors.success),
                        ),
                        const SizedBox(width: AppSizes.xs),
                        Expanded(child: Text(tip, style: AppTextStyles.caption)),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  path == null ? 'Добавить фото' : 'Заменить или удалить',
                  style: AppTextStyles.link.copyWith(color: AppColors.accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
