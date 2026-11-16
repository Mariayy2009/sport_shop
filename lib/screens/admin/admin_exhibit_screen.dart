import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../data/repositories/exhibit_repository.dart';
import '../../models/exhibit.dart';
import '../../models/sport.dart';
import '../../services/media_storage.dart';
import '../../state/auth_state.dart';
import '../../state/product_state.dart';
import '../../widgets/app_dropdown_field.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/photo_action_sheet.dart';
import '../../widgets/product_image.dart';

/// Добавление и редактирование экспоната «Зала славы».
/// Возвращает true, если список экспонатов изменился.
class AdminExhibitScreen extends StatefulWidget {
  const AdminExhibitScreen({super.key, this.exhibit});

  /// null — создаётся новый экспонат.
  final Exhibit? exhibit;

  @override
  State<AdminExhibitScreen> createState() => _AdminExhibitScreenState();
}

class _AdminExhibitScreenState extends State<AdminExhibitScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _title =
      TextEditingController(text: widget.exhibit?.title ?? '');
  late final TextEditingController _athlete =
      TextEditingController(text: widget.exhibit?.athlete ?? '');
  late final TextEditingController _year =
      TextEditingController(text: widget.exhibit?.year ?? '');
  late final TextEditingController _story =
      TextEditingController(text: widget.exhibit?.story ?? '');
  late int? _sportId = widget.exhibit?.sportId;
  late ExhibitSource _source = widget.exhibit?.source ?? ExhibitSource.knus;
  late String? _imageUrl = widget.exhibit?.imageUrl;
  bool _isSaving = false;

  bool get _isNew => widget.exhibit == null;

  @override
  void dispose() {
    _title.dispose();
    _athlete.dispose();
    _year.dispose();
    _story.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final MediaStorage storage = context.read<MediaStorage>();
    final int? adminId = context.read<AuthState>().currentUser?.id;
    final PhotoAction? action = await PhotoActionSheet.show(
      context,
      title: 'Фото экспоната',
      canDelete: _imageUrl != null,
    );
    if (action == null || adminId == null) return;
    if (action == PhotoAction.delete) {
      setState(() => _imageUrl = null);
      return;
    }
    try {
      final String? path = await storage.pickAndSave(
        userId: adminId,
        kind: PhotoKind.exhibit,
        source: action == PhotoAction.camera
            ? PhotoSource.camera
            : PhotoSource.gallery,
      );
      if (path != null && mounted) setState(() => _imageUrl = path);
    } on Exception catch (error) {
      debugPrint('Не удалось выбрать фото экспоната: $error');
      if (mounted) AppMessages.showError(context, 'Не удалось получить фото');
    }
  }

  String? _nullIfEmpty(TextEditingController controller) {
    final String text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      AppMessages.showWarning(context, 'Проверьте правильность заполнения полей');
      return;
    }
    final ExhibitRepository repository = context.read<ExhibitRepository>();
    final NavigatorState navigator = Navigator.of(context);
    setState(() => _isSaving = true);
    await repository.save(Exhibit(
      id: widget.exhibit?.id,
      title: _title.text.trim(),
      athlete: _athlete.text.trim(),
      sportId: _sportId,
      year: _nullIfEmpty(_year),
      story: _nullIfEmpty(_story),
      imageUrl: _imageUrl,
      source: _source,
      createdAt: widget.exhibit?.createdAt ?? DateTime.now(),
    ));
    if (!mounted) return;
    AppMessages.showSuccess(
      context,
      _isNew ? 'Экспонат добавлен' : 'Экспонат сохранён',
    );
    navigator.pop(true);
  }

  Future<void> _delete() async {
    final ExhibitRepository repository = context.read<ExhibitRepository>();
    final NavigatorState navigator = Navigator.of(context);
    final bool confirmed = await AppMessages.showConfirmDialog(
      context,
      title: 'Удалить экспонат?',
      message: '«${widget.exhibit!.title}» исчезнет из Зала славы',
      confirmText: 'Удалить',
      isDestructive: true,
    );
    if (!confirmed) return;
    await repository.delete(widget.exhibit!.id!);
    if (!mounted) return;
    AppMessages.showSuccess(context, 'Экспонат удалён');
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthState>().isAdmin) {
      return const AppScaffold(
        title: 'Экспонат',
        navTab: MainTab.home,
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'Нет доступа',
          message: 'Экспонаты добавляет администратор магазина',
        ),
      );
    }
    final List<Sport> sports = context.watch<ProductState>().sports;
    return AppScaffold(
      title: _isNew ? 'Новый экспонат' : 'Редактирование экспоната',
      navTab: MainTab.home,
      titleTrailing: _isNew
          ? null
          : IconButton(
              tooltip: 'Удалить экспонат',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
            ),
      bottomAction: CustomButton(
        text: 'Сохранить',
        isLoading: _isSaving,
        onPressed: _save,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          children: [
            Row(
              children: [
                ProductImage(
                  imageUrl: _imageUrl,
                  width: 96,
                  height: 96,
                  placeholderIcon: Icons.emoji_events_outlined,
                ),
                const SizedBox(width: AppSizes.l),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Фото экспоната', style: AppTextStyles.sectionTitle),
                      const Text(
                        'Снимайте без бликов на стекле витрины',
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: AppSizes.xs),
                      TextButton(
                        onPressed: _pickImage,
                        child: Text(
                          _imageUrl == null ? 'Добавить фото' : 'Заменить фото',
                          style: const TextStyle(color: AppColors.accent),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.l),
            const Text('Откуда экспонат', style: AppTextStyles.fieldLabel),
            const SizedBox(height: AppSizes.xs),
            SegmentedButton<ExhibitSource>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                backgroundColor: AppColors.surface,
                selectedBackgroundColor: AppColors.black,
                selectedForegroundColor: AppColors.white,
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
              ),
              segments: [
                for (final ExhibitSource source in ExhibitSource.values)
                  ButtonSegment(value: source, label: Text(source.fullLabel)),
              ],
              selected: {_source},
              onSelectionChanged: (value) => setState(() => _source = value.first),
            ),
            const SizedBox(height: AppSizes.m),
            AppTextField(
              label: 'Что это за вещь',
              hint: 'Например: игровая майка',
              controller: _title,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) =>
                  (value?.trim().length ?? 0) < 3 ? 'Опишите экспонат' : null,
            ),
            const SizedBox(height: AppSizes.m),
            AppTextField(
              label: 'Чья вещь',
              hint: 'Имя и фамилия спортсмена',
              controller: _athlete,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              validator: (value) =>
                  (value?.trim().length ?? 0) < 3 ? 'Укажите спортсмена' : null,
            ),
            const SizedBox(height: AppSizes.m),
            AppDropdownField<int>(
              label: 'Вид спорта',
              hint: 'По нему подбираются похожие товары',
              value: _sportId,
              items: [
                for (final Sport sport in sports)
                  DropdownMenuItem(value: sport.id, child: Text(sport.name)),
              ],
              onChanged: (value) => setState(() => _sportId = value),
            ),
            const SizedBox(height: AppSizes.m),
            AppTextField(
              label: 'Год или период',
              hint: '2012 или 2016–2020',
              controller: _year,
              maxLength: 20,
            ),
            const SizedBox(height: AppSizes.m),
            AppTextField(
              label: 'История экспоната',
              hint: 'Достижение, соревнование, факты с таблички',
              controller: _story,
              maxLength: 600,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }
}
