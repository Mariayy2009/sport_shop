import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../core/utils/validators.dart';
import '../../models/sport.dart';
import '../../models/user.dart';
import '../../models/user_sizes.dart';
import '../../state/auth_state.dart';
import '../../state/product_state.dart';
import '../../state/profile_state.dart';
import '../../widgets/app_dropdown_field.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/size_selector.dart';

/// Редактирование профиля: данные users + параметры user_sizes.
/// Экрана нет в Figma — добавлен, так как этого требует сценарий 4.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _shoeSize;
  late final TextEditingController _experience;
  late final TextEditingController _email;

  int? _sportId;
  String? _clothingSize;
  bool _hasChanges = false;
  bool _wasSubmitted = false;
  bool _sizeError = false;

  @override
  void initState() {
    super.initState();
    final User user = context.read<AuthState>().currentUser!;
    final UserSizes? sizes = context.read<ProfileState>().sizes;
    _firstName = TextEditingController(text: user.firstName ?? '');
    _lastName = TextEditingController(text: user.lastName ?? '');
    _phone = TextEditingController(text: user.phone ?? '');
    _height = TextEditingController(text: sizes?.height?.toString() ?? '');
    _weight = TextEditingController(text: sizes?.weight?.toString() ?? '');
    _shoeSize = TextEditingController(text: sizes?.shoeSize?.toString() ?? '');
    _experience =
        TextEditingController(text: sizes?.experienceYears?.toString() ?? '');
    _email = TextEditingController(text: user.email);
    _sportId = sizes?.sportId;
    _clothingSize = sizes?.clothingSize;
  }

  @override
  void dispose() {
    for (final TextEditingController controller in [
      _firstName,
      _lastName,
      _phone,
      _height,
      _weight,
      _shoeSize,
      _experience,
      _email,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  String? _range(String? value, int min, int max, String empty, String unit) {
    return Validators.intInRange(
      value,
      min: min,
      max: max,
      emptyMessage: empty,
      rangeMessage: 'Допустимо от $min до $max$unit',
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _wasSubmitted = true;
      _sizeError = _clothingSize == null;
    });
    final bool isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _clothingSize == null || _sportId == null) {
      AppMessages.showError(
        context,
        _clothingSize == null
            ? 'Выберите размер одежды'
            : (_sportId == null
                ? 'Выберите основной вид спорта'
                : 'Проверьте правильность заполнения полей'),
      );
      return;
    }

    final AuthState authState = context.read<AuthState>();
    final ProfileState profileState = context.read<ProfileState>();
    final User user = authState.currentUser!;
    final String phone = _phone.text.trim();

    try {
      final User updated = await profileState.saveProfile(
        user: user.copyWith(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          phone: phone,
        ),
        sizes: UserSizes(
          id: profileState.sizes?.id,
          userId: user.id!,
          height: int.parse(_height.text.trim()),
          weight: int.parse(_weight.text.trim()),
          clothingSize: _clothingSize,
          shoeSize: int.parse(_shoeSize.text.trim()),
          experienceYears: int.parse(_experience.text.trim()),
          sportId: _sportId,
        ),
      );
      authState.updateCurrentUser(updated);
      if (!mounted) return;
      _hasChanges = false;
      AppMessages.showSuccess(context, 'Профиль сохранён');
      Navigator.of(context).pop();
    } catch (error) {
      debugPrint('Ошибка сохранения профиля: $error');
      if (!mounted) return;
      AppMessages.showError(context, 'Не удалось сохранить профиль');
    }
  }

  Future<void> _confirmLeave() async {
    final bool leave = await AppMessages.showConfirmDialog(
      context,
      title: 'Несохранённые изменения',
      message: 'Выйти без сохранения? Внесённые изменения будут потеряны.',
      confirmText: 'Выйти',
      isDestructive: true,
    );
    if (leave && mounted) {
      _hasChanges = false;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Sport> sports = context.watch<ProductState>().sports;
    final bool isSaving = context.watch<ProfileState>().isSaving;
    final List<TextInputFormatter> digits = [
      FilteringTextInputFormatter.digitsOnly,
    ];

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmLeave();
      },
      child: AppScaffold(
        title: 'Редактирование профиля',
        navTab: MainTab.profile,
        bottomAction: CustomButton(
          text: 'Сохранить',
          isLoading: isSaving,
          onPressed: _save,
        ),
        body: Form(
          key: _formKey,
          onChanged: _markChanged,
          autovalidateMode: _wasSubmitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            children: [
              const Text('Личные данные', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSizes.s),
              AppTextField(
                label: 'Имя',
                controller: _firstName,
                textCapitalization: TextCapitalization.words,
                maxLength: Validators.nameMaxLength,
                validator: (v) => Validators.name(v, emptyMessage: 'Введите имя'),
              ),
              const SizedBox(height: AppSizes.m),
              AppTextField(
                label: 'Фамилия',
                controller: _lastName,
                textCapitalization: TextCapitalization.words,
                maxLength: Validators.nameMaxLength,
                validator: (v) =>
                    Validators.name(v, emptyMessage: 'Введите фамилию'),
              ),
              const SizedBox(height: AppSizes.m),
              AppTextField(
                label: 'Телефон',
                hint: '+7 700 000 00 00',
                controller: _phone,
                keyboardType: TextInputType.phone,
                maxLength: 18,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+() -]')),
                ],
                validator: Validators.phone,
              ),
              const SizedBox(height: AppSizes.m),
              AppTextField(
                label: 'Email (изменить нельзя)',
                controller: _email,
                enabled: false,
              ),
              const SizedBox(height: AppSizes.xl),
              const Text('Спорт', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSizes.s),
              AppDropdownField<int>(
                label: 'Основной вид спорта',
                value: _sportId,
                hint: 'Выберите вид спорта',
                validator: (value) =>
                    value == null ? 'Выберите вид спорта' : null,
                onChanged: (value) => setState(() {
                  _sportId = value;
                  _hasChanges = true;
                }),
                items: [
                  for (final Sport sport in sports)
                    DropdownMenuItem<int>(value: sport.id, child: Text(sport.name)),
                ],
              ),
              const SizedBox(height: AppSizes.m),
              AppTextField(
                label: 'Стаж, лет',
                controller: _experience,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                maxLength: 2,
                validator: (v) => _range(v, UserSizes.minExperience,
                    UserSizes.maxExperience, 'Введите стаж', ' лет'),
              ),
              const SizedBox(height: AppSizes.xl),
              const Text('Параметры', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSizes.s),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Рост, см',
                      controller: _height,
                      keyboardType: TextInputType.number,
                      inputFormatters: digits,
                      maxLength: 3,
                      validator: (v) => _range(v, UserSizes.minHeight,
                          UserSizes.maxHeight, 'Введите рост', ' см'),
                    ),
                  ),
                  const SizedBox(width: AppSizes.m),
                  Expanded(
                    child: AppTextField(
                      label: 'Вес, кг',
                      controller: _weight,
                      keyboardType: TextInputType.number,
                      inputFormatters: digits,
                      maxLength: 3,
                      validator: (v) => _range(v, UserSizes.minWeight,
                          UserSizes.maxWeight, 'Введите вес', ' кг'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.m),
              AppTextField(
                label: 'Размер обуви (EU)',
                controller: _shoeSize,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                maxLength: 2,
                validator: (v) => _range(v, UserSizes.minShoeSize,
                    UserSizes.maxShoeSize, 'Введите размер обуви', ''),
              ),
              const SizedBox(height: AppSizes.m),
              const Padding(
                padding: EdgeInsets.only(left: AppSizes.s, bottom: AppSizes.s),
                child: Text('Размер одежды', style: AppTextStyles.fieldLabel),
              ),
              SizeSelector(
                sizes: UserSizes.clothingSizes,
                selected: _clothingSize,
                hasError: _sizeError,
                onSelected: (size) => setState(() {
                  _clothingSize = size;
                  _sizeError = false;
                  _hasChanges = true;
                }),
              ),
              if (_sizeError)
                const Padding(
                  padding: EdgeInsets.only(top: AppSizes.xs, left: AppSizes.s),
                  child: Text('Выберите размер одежды',
                      style: AppTextStyles.fieldError),
                ),
              const SizedBox(height: AppSizes.xl),
            ],
          ),
        ),
      ),
    );
  }
}
