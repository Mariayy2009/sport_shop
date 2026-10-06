import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/enums.dart';
import '../../models/sport.dart';
import '../../models/user.dart';
import '../../models/user_sizes.dart';
import '../../state/auth_state.dart';
import '../../state/product_state.dart';
import '../../state/profile_state.dart';
import '../../state/recommendation_state.dart';
import '../../widgets/app_dropdown_field.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/choice_option.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/labeled_checkbox.dart';
import '../../widgets/sport_option_tile.dart';

/// Опрос AI-подбора — три шага (фреймы Figma «ии2», «ии3», «ии4»):
/// 1) вид спорта; 2) уровень и стаж; 3) параметры и бюджет.
class RecommendationQuizScreen extends StatefulWidget {
  const RecommendationQuizScreen({super.key});

  @override
  State<RecommendationQuizScreen> createState() =>
      _RecommendationQuizScreenState();
}

class _RecommendationQuizScreenState extends State<RecommendationQuizScreen> {
  static const int _stepsCount = 3;

  final GlobalKey<FormState> _levelFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _paramsFormKey = GlobalKey<FormState>();
  late final TextEditingController _experience;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _shoeSize;

  int _step = 0;
  bool _showSportError = false;
  bool _showLevelError = false;
  bool _saveToProfile = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final RecommendationState state = context.read<RecommendationState>();
    _experience =
        TextEditingController(text: state.experienceYears?.toString() ?? '');
    _height = TextEditingController(text: state.height?.toString() ?? '');
    _weight = TextEditingController(text: state.weight?.toString() ?? '');
    _shoeSize = TextEditingController(text: state.shoeSize?.toString() ?? '');
  }

  @override
  void dispose() {
    _experience.dispose();
    _height.dispose();
    _weight.dispose();
    _shoeSize.dispose();
    super.dispose();
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

  void _back() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    final RecommendationState state = context.read<RecommendationState>();

    switch (_step) {
      case 0:
        if (state.sportId == null) {
          setState(() => _showSportError = true);
          AppMessages.showWarning(context, 'Выберите вид спорта');
          return;
        }
      case 1:
        final bool formValid = _levelFormKey.currentState?.validate() ?? false;
        if (state.level == null) {
          setState(() => _showLevelError = true);
          AppMessages.showWarning(context, 'Выберите уровень подготовки');
          return;
        }
        if (!formValid) {
          AppMessages.showError(context, 'Укажите стаж занятий');
          return;
        }
        final int years = int.parse(_experience.text.trim());
        state.setExperience(years);
        // Предупреждение, если уровень не совпадает со стажем — не ошибка.
        if (state.level == SportLevel.beginner && years >= 3) {
          AppMessages.showWarning(
            context,
            'Со стажем ${Formatters.years(years)} обычно выбирают '
            'уровень выше — подборка учтёт выбранный уровень',
          );
        }
      case 2:
        await _submit(state);
        return;
    }
    setState(() => _step++);
  }

  Future<void> _submit(RecommendationState state) async {
    final bool formValid = _paramsFormKey.currentState?.validate() ?? false;
    if (!formValid || state.clothingSize == null) {
      AppMessages.showError(
        context,
        state.clothingSize == null
            ? 'Выберите размер одежды'
            : 'Проверьте параметры',
      );
      return;
    }
    state.setParameters(
      height: int.parse(_height.text.trim()),
      weight: int.parse(_weight.text.trim()),
      clothingSize: state.clothingSize!,
      shoeSize: int.parse(_shoeSize.text.trim()),
    );

    setState(() => _isSubmitting = true);
    final User? user = context.read<AuthState>().currentUser;
    final ProfileState profileState = context.read<ProfileState>();
    final NavigatorState navigator = Navigator.of(context);

    if (_saveToProfile && user?.id != null) {
      try {
        await profileState.saveSizes(UserSizes(
          id: profileState.sizes?.id,
          userId: user!.id!,
          height: state.height,
          weight: state.weight,
          clothingSize: state.clothingSize,
          shoeSize: state.shoeSize,
          experienceYears: state.experienceYears,
          sportId: state.sportId,
        ));
      } catch (error) {
        debugPrint('Не удалось сохранить параметры: $error');
      }
    }
    await state.loadRecommendations();
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    navigator.pushNamed(AppRoutes.recommendationResult);
  }

  @override
  Widget build(BuildContext context) {
    final RecommendationState state = context.watch<RecommendationState>();
    final bool isLast = _step == _stepsCount - 1;

    return AppScaffold(
      title: 'Подбор экипировки',
      navTab: MainTab.ai,
      bottomAction: Row(
        children: [
          Expanded(
            child: CustomButton(
              text: 'Назад',
              variant: ButtonVariant.secondary,
              onPressed: _back,
            ),
          ),
          const SizedBox(width: AppSizes.m),
          Expanded(
            child: CustomButton(
              text: isLast ? 'Получить подборку' : 'Далее',
              isLoading: _isSubmitting,
              onPressed: _next,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        children: [
          _StepIndicator(step: _step, total: _stepsCount),
          const SizedBox(height: AppSizes.l),
          switch (_step) {
            0 => _buildSportStep(state),
            1 => _buildLevelStep(state),
            _ => _buildParamsStep(state),
          },
        ],
      ),
    );
  }

  Widget _buildSportStep(RecommendationState state) {
    final List<Sport> sports = context.watch<ProductState>().sports;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Какой у тебя вид спорта?', style: AppTextStyles.questionTitle),
        if (_showSportError && state.sportId == null)
          const Padding(
            padding: EdgeInsets.only(top: AppSizes.xs),
            child: Text('Выберите один вариант', style: AppTextStyles.fieldError),
          ),
        const SizedBox(height: AppSizes.m),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSizes.s,
          crossAxisSpacing: AppSizes.s,
          childAspectRatio: 1.5,
          children: [
            for (final Sport sport in sports)
              SportOptionTile(
                sportName: sport.name,
                isSelected: state.sportId == sport.id,
                onTap: () {
                  setState(() => _showSportError = false);
                  context.read<RecommendationState>().selectSport(sport.id!);
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLevelStep(RecommendationState state) {
    return Form(
      key: _levelFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Твой уровень?', style: AppTextStyles.questionTitle),
          const SizedBox(height: AppSizes.m),
          for (final SportLevel level in SportLevel.values) ...[
            ChoiceOption(
              label: level.fullLabel,
              isSelected: state.level == level,
              hasError: _showLevelError && state.level == null,
              onTap: () {
                setState(() => _showLevelError = false);
                context.read<RecommendationState>().selectLevel(level);
              },
            ),
            const SizedBox(height: AppSizes.s),
          ],
          const SizedBox(height: AppSizes.l),
          AppTextField(
            label: 'Сколько лет занимаешься?',
            hint: 'Например, 2',
            controller: _experience,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 2,
            validator: (v) => _range(v, UserSizes.minExperience,
                UserSizes.maxExperience, 'Укажите стаж (0, если только начинаешь)', ' лет'),
          ),
        ],
      ),
    );
  }

  Widget _buildParamsStep(RecommendationState state) {
    final List<TextInputFormatter> digits = [
      FilteringTextInputFormatter.digitsOnly,
    ];
    final int divisions = ((RecommendationState.maxBudget -
                RecommendationState.minBudget) /
            RecommendationState.budgetStep)
        .round();

    return Form(
      key: _paramsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Твои параметры', style: AppTextStyles.questionTitle),
          const SizedBox(height: AppSizes.m),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppDropdownField<String>(
                  label: 'Размер одежды',
                  value: state.clothingSize,
                  hint: 'Выбрать',
                  validator: (value) => value == null ? 'Выберите размер' : null,
                  onChanged: (value) {
                    context.read<RecommendationState>().clothingSize = value;
                    setState(() {});
                  },
                  items: [
                    for (final String size in UserSizes.clothingSizes)
                      DropdownMenuItem<String>(value: size, child: Text(size)),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.m),
              Expanded(
                child: AppTextField(
                  label: 'Размер обуви',
                  controller: _shoeSize,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  maxLength: 2,
                  validator: (v) => _range(v, UserSizes.minShoeSize,
                      UserSizes.maxShoeSize, 'Введите размер', ''),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xl),
          Row(
            children: [
              const Expanded(
                child: Text('Бюджет', style: AppTextStyles.questionTitle),
              ),
              Text(
                'до ${Formatters.price(state.budget)}',
                style: AppTextStyles.price,
              ),
            ],
          ),
          Slider(
            value: state.budget,
            min: RecommendationState.minBudget,
            max: RecommendationState.maxBudget,
            divisions: divisions,
            activeColor: AppColors.black,
            inactiveColor: AppColors.border,
            label: Formatters.price(state.budget),
            onChanged: context.read<RecommendationState>().setBudget,
          ),
          const Text(
            'Обязательная экипировка подбирается в любом случае, '
            'бюджет ограничивает дополнительные товары',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSizes.l),
          LabeledCheckbox(
            value: _saveToProfile,
            label: 'Сохранить параметры в профиль',
            onChanged: (value) => setState(() => _saveToProfile = value),
          ),
        ],
      ),
    );
  }
}

/// «Шаг 1 из 3» + полоса прогресса.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Шаг ${step + 1} из $total', style: AppTextStyles.bodySecondary),
        const SizedBox(height: AppSizes.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          child: LinearProgressIndicator(
            value: (step + 1) / total,
            minHeight: 6,
            color: AppColors.black,
            backgroundColor: AppColors.surface,
          ),
        ),
      ],
    );
  }
}
