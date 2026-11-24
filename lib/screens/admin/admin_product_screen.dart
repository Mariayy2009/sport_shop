import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../core/utils/validators.dart';
import '../../data/repositories/product_repository.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../models/sport.dart';
import '../../services/media_storage.dart';
import '../../state/auth_state.dart';
import '../../state/product_state.dart';
import '../../widgets/app_dropdown_field.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/photo_action_sheet.dart';
import '../../widgets/product_image.dart';

/// Добавление и редактирование товара администратором.
/// Возвращает true, если каталог изменился.
class AdminProductScreen extends StatefulWidget {
  const AdminProductScreen({super.key, this.product, this.sellerId});

  /// null — создаётся новый товар.
  final Product? product;

  /// Продавец, который добавляет товар из своего кабинета.
  final int? sellerId;

  @override
  State<AdminProductScreen> createState() => _AdminProductScreenState();
}

class _AdminProductScreenState extends State<AdminProductScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _sizes;
  late final TextEditingController _brand;
  late final TextEditingController _material;
  int? _sportId;
  int? _categoryId;
  String? _imageUrl;
  bool _isSaving = false;

  bool get _isNew => widget.product == null;

  @override
  void initState() {
    super.initState();
    final Product? product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _description = TextEditingController(text: product?.description ?? '');
    _price = TextEditingController(
      text: product == null ? '' : product.price.round().toString(),
    );
    _stock = TextEditingController(text: product?.stock.toString() ?? '');
    _sizes = TextEditingController(text: product?.size ?? '');
    // Новый товар продавца — сразу с названием его магазина.
    _brand = TextEditingController(
      text: product?.brand ??
          (widget.sellerId == null
              ? ''
              : context.read<AuthState>().currentUser?.shopName ?? ''),
    );
    _material = TextEditingController(text: product?.material ?? '');
    _sportId = product?.sportId;
    _categoryId = product?.categoryId;
    _imageUrl = product?.imageUrl;
  }

  @override
  void dispose() {
    for (final TextEditingController controller in [
      _name,
      _description,
      _price,
      _stock,
      _sizes,
      _brand,
      _material,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final MediaStorage storage = context.read<MediaStorage>();
    final int? adminId = context.read<AuthState>().currentUser?.id;
    final PhotoAction? action = await PhotoActionSheet.show(
      context,
      title: 'Фото товара',
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
        kind: PhotoKind.product,
        source: action == PhotoAction.camera
            ? PhotoSource.camera
            : PhotoSource.gallery,
      );
      if (path != null && mounted) setState(() => _imageUrl = path);
    } on Exception catch (error) {
      debugPrint('Не удалось выбрать фото товара: $error');
      if (mounted) {
        AppMessages.showError(context, 'Не удалось получить фото');
      }
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
    final ProductRepository repository = context.read<ProductRepository>();
    final ProductState catalog = context.read<ProductState>();
    final NavigatorState navigator = Navigator.of(context);
    setState(() => _isSaving = true);

    // Размеры храним без пробелов: «S,M,L».
    final String sizes = _sizes.text
        .split(',')
        .map((size) => size.trim())
        .where((size) => size.isNotEmpty)
        .join(',');
    final Product draft = Product(
      id: widget.product?.id,
      name: _name.text.trim(),
      description: _nullIfEmpty(_description),
      price: double.parse(_price.text.trim()),
      categoryId: _categoryId!,
      sportId: _sportId!,
      size: sizes.isEmpty ? null : sizes,
      stock: int.parse(_stock.text.trim()),
      imageUrl: _imageUrl,
      // Дополнительные фото в форме не редактируются — сохраняем как были.
      gallery: widget.product?.gallery ?? const [],
      variants: widget.product?.variants ?? const [],
      brand: _nullIfEmpty(_brand),
      material: _nullIfEmpty(_material),
      rating: widget.product?.rating,
      reviewsCount: widget.product?.reviewsCount ?? 0,
      // Продавец и статус модерации при правке не меняются. Новый товар
      // продавца — его товар; новый товар администратора — магазина SPORT.
      sellerId: widget.product?.sellerId ?? widget.sellerId,
      isBlocked: widget.product?.isBlocked ?? false,
      blockReason: widget.product?.blockReason,
    );
    try {
      if (_isNew) {
        await repository.createProduct(draft);
      } else {
        await repository.updateProduct(draft);
      }
      await catalog.init();
      if (!mounted) return;
      AppMessages.showSuccess(context, _isNew ? 'Товар добавлен' : 'Товар сохранён');
      navigator.pop(true);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppMessages.showInfoDialog(context, title: 'Не сохранено', message: error.message);
    } on Exception catch (error) {
      debugPrint('Ошибка сохранения товара: $error');
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppMessages.showError(context, 'Не удалось сохранить товар');
    }
  }

  Future<void> _delete() async {
    final ProductRepository repository = context.read<ProductRepository>();
    final ProductState catalog = context.read<ProductState>();
    final NavigatorState navigator = Navigator.of(context);
    final bool confirmed = await AppMessages.showConfirmDialog(
      context,
      title: 'Удалить товар?',
      message: '«${widget.product!.name}» исчезнет из каталога',
      confirmText: 'Удалить',
      isDestructive: true,
    );
    if (!confirmed) return;
    try {
      await repository.deleteProduct(widget.product!.id!);
      await catalog.init();
      if (!mounted) return;
      AppMessages.showSuccess(context, 'Товар удалён');
      navigator.pop(true);
    } on AppException catch (error) {
      if (!mounted) return;
      AppMessages.showInfoDialog(context, title: 'Не удалено', message: error.message);
    } on Exception {
      // Товар есть в заказах: история покупок должна сохраниться.
      if (!mounted) return;
      AppMessages.showInfoDialog(
        context,
        title: 'Товар нельзя удалить',
        message: 'Он есть в заказах покупателей. Чтобы снять товар '
            'с продажи, укажите остаток 0.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProductState catalog = context.watch<ProductState>();
    return AppScaffold(
      title: _isNew ? 'Новый товар' : 'Редактирование товара',
      navTab: MainTab.profile,
      titleTrailing: _isNew
          ? null
          : IconButton(
              tooltip: 'Удалить товар',
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
                ProductImage(imageUrl: _imageUrl, width: 96, height: 96),
                const SizedBox(width: AppSizes.l),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Фото товара', style: AppTextStyles.sectionTitle),
                      const Text(
                        'Светлый фон, товар целиком в кадре',
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
            AppTextField(
              label: 'Название',
              controller: _name,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'Введите название (от 3 символов)'
                  : null,
            ),
            const SizedBox(height: AppSizes.m),
            AppTextField(
              label: 'Описание',
              controller: _description,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSizes.m),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Цена, ₸',
                    controller: _price,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 8,
                    validator: (value) => Validators.intInRange(
                      value,
                      min: 1,
                      max: 99999999,
                      emptyMessage: 'Укажите цену',
                      rangeMessage: 'Цена должна быть больше 0',
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.m),
                Expanded(
                  child: AppTextField(
                    label: 'Остаток, шт.',
                    controller: _stock,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 5,
                    validator: (value) => Validators.intInRange(
                      value,
                      min: 0,
                      max: 99999,
                      emptyMessage: 'Укажите остаток',
                      rangeMessage: 'От 0 до 99 999',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.m),
            AppDropdownField<int>(
              label: 'Вид спорта',
              hint: 'Выберите вид спорта',
              value: _sportId,
              items: [
                for (final Sport sport in catalog.sports)
                  DropdownMenuItem(value: sport.id, child: Text(sport.name)),
              ],
              validator: (value) => value == null ? 'Выберите вид спорта' : null,
              onChanged: (value) => setState(() => _sportId = value),
            ),
            const SizedBox(height: AppSizes.m),
            AppDropdownField<int>(
              label: 'Категория',
              hint: 'Выберите категорию',
              value: _categoryId,
              items: [
                for (final ProductCategory category in catalog.categories)
                  DropdownMenuItem(value: category.id, child: Text(category.name)),
              ],
              validator: (value) => value == null ? 'Выберите категорию' : null,
              onChanged: (value) => setState(() => _categoryId = value),
            ),
            const SizedBox(height: AppSizes.m),
            AppTextField(
              label: 'Размеры через запятую',
              hint: 'S, M, L или 38, 39, 40 — пусто, если без размера',
              controller: _sizes,
              maxLength: 60,
            ),
            const SizedBox(height: AppSizes.m),
            AppTextField(label: 'Бренд', controller: _brand, maxLength: 40),
            const SizedBox(height: AppSizes.m),
            AppTextField(label: 'Материал', controller: _material, maxLength: 60),
          ],
        ),
      ),
    );
  }
}
