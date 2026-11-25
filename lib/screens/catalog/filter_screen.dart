import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../core/utils/formatters.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../models/product_filter.dart';
import '../../models/sport.dart';
import '../../state/product_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dropdown_field.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/custom_button.dart';

/// Фильтры каталога (фрейм Figma «фильтр»).
class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  static const int _maxPrice = 1000000;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _queryController;
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;

  int? _sportId;
  int? _categoryId;
  String? _size;
  bool _onlyAvailable = false;
  Set<String> _diet = {};

  @override
  void initState() {
    super.initState();
    final ProductFilter filter = context.read<ProductState>().filter;
    _queryController = TextEditingController(text: filter.query);
    _minPriceController =
        TextEditingController(text: filter.minPrice?.toStringAsFixed(0) ?? '');
    _maxPriceController =
        TextEditingController(text: filter.maxPrice?.toStringAsFixed(0) ?? '');
    _sportId = filter.sportId;
    _categoryId = filter.categoryId;
    _size = filter.size;
    _onlyAvailable = filter.onlyAvailable;
    _diet = {...filter.diet};
  }

  @override
  void dispose() {
    _queryController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  String? _validatePrice(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final int? price = int.tryParse(text);
    if (price == null) return 'Введите число';
    if (price > _maxPrice) return 'Не более ${Formatters.price(_maxPrice.toDouble())}';
    return null;
  }

  String? _validateMaxPrice(String? value) {
    final String? basic = _validatePrice(value);
    if (basic != null) return basic;
    final int? min = int.tryParse(_minPriceController.text.trim());
    final int? max = int.tryParse(value?.trim() ?? '');
    if (min != null && max != null && min > max) {
      return '«До» должно быть больше «от»';
    }
    return null;
  }

  void _resetFields() {
    setState(() {
      _queryController.clear();
      _minPriceController.clear();
      _maxPriceController.clear();
      _sportId = null;
      _categoryId = null;
      _size = null;
      _onlyAvailable = false;
      _diet = {};
    });
  }

  Future<void> _apply() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      AppMessages.showError(context, 'Проверьте диапазон цен');
      return;
    }
    final ProductState state = context.read<ProductState>();
    await state.applyFilter(ProductFilter(
      query: _queryController.text.trim(),
      sportId: _sportId,
      categoryId: _categoryId,
      size: _size,
      minPrice: double.tryParse(_minPriceController.text.trim()),
      maxPrice: double.tryParse(_maxPriceController.text.trim()),
      onlyAvailable: _onlyAvailable,
      diet: _diet,
    ));
    if (!mounted) return;
    AppMessages.showInfo(
      context,
      'Найдено: ${Formatters.itemsCount(state.products.length)}',
    );
    Navigator.of(context).pop();
  }

  Future<void> _resetAndApply() async {
    _resetFields();
    await context.read<ProductState>().applyFilter(const ProductFilter());
    if (!mounted) return;
    AppMessages.showInfo(context, 'Фильтры сброшены');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ProductState state = context.watch<ProductState>();
    final List<Sport> sports = state.sports;
    final List<ProductCategory> categories = state.categories;

    return AppScaffold(
      title: 'Фильтры',
      navTab: MainTab.catalog,
      titleTrailing: TextButton(
        onPressed: _resetFields,
        child: const Text('Сбросить'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          children: [
            AppTextField(
              label: 'Наименование товара',
              hint: 'Например, кроссовки',
              controller: _queryController,
              maxLength: 50,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppSizes.m),
            AppDropdownField<int?>(
              label: 'Вид спорта',
              value: _sportId,
              onChanged: (value) => setState(() => _sportId = value),
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('Все виды спорта')),
                for (final Sport sport in sports)
                  DropdownMenuItem<int?>(value: sport.id, child: Text(sport.name)),
              ],
            ),
            const SizedBox(height: AppSizes.m),
            AppDropdownField<int?>(
              label: 'Категория',
              value: _categoryId,
              onChanged: (value) => setState(() => _categoryId = value),
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('Все категории')),
                for (final ProductCategory category in categories)
                  DropdownMenuItem<int?>(
                      value: category.id, child: Text(category.name)),
              ],
            ),
            const SizedBox(height: AppSizes.m),
            AppDropdownField<String?>(
              label: 'Размер',
              value: _size,
              onChanged: (value) => setState(() => _size = value),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('Любой размер')),
                for (final String size in state.allSizes)
                  DropdownMenuItem<String?>(value: size, child: Text(size)),
              ],
            ),
            const SizedBox(height: AppSizes.m),
            const Padding(
              padding: EdgeInsets.only(left: AppSizes.s, bottom: AppSizes.xs),
              child: Text('Диапазон цен, ₸', style: AppTextStyles.fieldLabel),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minPriceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 7,
                    validator: _validatePrice,
                    style: AppTextStyles.body,
                    decoration: AppTextField.buildDecoration(hint: 'от'),
                  ),
                ),
                const SizedBox(width: AppSizes.s),
                Expanded(
                  child: TextFormField(
                    controller: _maxPriceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 7,
                    validator: _validateMaxPrice,
                    style: AppTextStyles.body,
                    decoration: AppTextField.buildDecoration(hint: 'до'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.m),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.l,
                vertical: AppSizes.xs,
              ),
              onTap: () => setState(() => _onlyAvailable = !_onlyAvailable),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Только в наличии', style: AppTextStyles.body),
                  ),
                  Switch(
                    value: _onlyAvailable,
                    activeTrackColor: AppColors.black,
                    onChanged: (value) => setState(() => _onlyAvailable = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.m),
            const Padding(
              padding: EdgeInsets.only(left: AppSizes.s, bottom: AppSizes.xs),
              child: Text('Спортивное питание', style: AppTextStyles.fieldLabel),
            ),
            Wrap(
              spacing: AppSizes.s,
              runSpacing: AppSizes.s,
              children: [
                for (final MapEntry<String, String> tag in DietTag.labels.entries)
                  FilterChip(
                    label: Text(tag.value),
                    selected: _diet.contains(tag.key),
                    showCheckmark: true,
                    checkmarkColor: AppColors.white,
                    selectedColor: AppColors.black,
                    labelStyle: AppTextStyles.body.copyWith(
                      color: _diet.contains(tag.key)
                          ? AppColors.white
                          : AppColors.textPrimary,
                    ),
                    onSelected: (on) => setState(() {
                      _diet = on ? {..._diet, tag.key} : ({..._diet}..remove(tag.key));
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.xl),
            CustomButton(text: 'Применить', onPressed: _apply),
            const SizedBox(height: AppSizes.m),
            CustomButton(
              text: 'Сбросить все',
              variant: ButtonVariant.secondary,
              onPressed: _resetAndApply,
            ),
          ],
        ),
      ),
    );
  }
}
