import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/cart_item.dart';
import '../../models/item_options.dart';
import '../../models/enums.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../../state/auth_state.dart';
import '../../state/cart_state.dart';
import '../../state/order_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/summary_row.dart';

/// Оформление заказа (фрейм Figma «заказ»).
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const String _pickupPoint =
      'г. Астана, пр. Мангилик Ел, 55, ТРЦ «Sport City», ежедневно 10:00–22:00';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  final TextEditingController _address = TextEditingController();

  DeliveryMethod _deliveryMethod = DeliveryMethod.courier;
  bool _wasSubmitted = false;

  @override
  void initState() {
    super.initState();
    final User? user = context.read<AuthState>().currentUser;
    _name = TextEditingController(text: user?.fullName ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _email = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  String? _validateAddress(String? value) {
    if (_deliveryMethod != DeliveryMethod.courier) return null;
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return 'Введите адрес доставки';
    if (text.length < 10) return 'Укажите улицу, дом и квартиру';
    return null;
  }

  Future<void> _confirm() async {
    FocusScope.of(context).unfocus();
    setState(() => _wasSubmitted = true);
    if (!(_formKey.currentState?.validate() ?? false)) {
      AppMessages.showError(context, 'Заполните данные для доставки');
      return;
    }

    final CartState cart = context.read<CartState>();
    final OrderState orders = context.read<OrderState>();
    final User user = context.read<AuthState>().currentUser!;
    final double total =
        cart.itemsTotal + OrderState.deliveryPrice(_deliveryMethod);

    final bool confirmed = await AppMessages.showConfirmDialog(
      context,
      title: 'Подтвердите заказ',
      message: '${Formatters.itemsCount(cart.totalQuantity)} на сумму '
          '${Formatters.price(total)}.\nОплата при получении.',
      confirmText: 'Подтвердить',
    );
    if (!confirmed || !mounted) return;

    try {
      final Order order = await orders.placeOrder(
        userId: user.id!,
        items: cart.items,
        customerName: _name.text,
        phone: _phone.text,
        deliveryMethod: _deliveryMethod,
        address: _address.text,
      );
      await cart.clear();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.orderSuccess,
        (route) => false,
        arguments: order,
      );
    } on AppException catch (error) {
      if (!mounted) return;
      AppMessages.showError(context, error.message);
    } catch (error) {
      debugPrint('Ошибка оформления заказа: $error');
      if (!mounted) return;
      AppMessages.showError(context, 'Не удалось оформить заказ. Попробуйте ещё раз');
    }
  }

  @override
  Widget build(BuildContext context) {
    final CartState cart = context.watch<CartState>();
    final bool isPlacing = context.watch<OrderState>().isPlacing;
    final double delivery = OrderState.deliveryPrice(_deliveryMethod);

    if (cart.isEmpty) {
      return AppScaffold(
        title: 'Оформление заказа',
        navTab: MainTab.basket,
        body: EmptyState(
          icon: Icons.shopping_basket_outlined,
          title: 'Корзина пуста',
          message: 'Нечего оформлять — добавьте товары в корзину',
          actionText: 'В каталог',
          onAction: () => Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.main,
            (route) => false,
            arguments: MainTab.catalog,
          ),
        ),
      );
    }

    return AppScaffold(
      title: 'Оформление заказа',
      navTab: MainTab.basket,
      bottomAction: CustomButton(
        text: 'Подтвердить заказ',
        isLoading: isPlacing,
        onPressed: _confirm,
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: _wasSubmitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          children: [
            AppTextField(
              label: 'Имя',
              controller: _name,
              textCapitalization: TextCapitalization.words,
              maxLength: 60,
              validator: (value) =>
                  Validators.requiredField(value, 'Введите имя получателя'),
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
            AppTextField(label: 'Email', controller: _email, enabled: false),
            const SizedBox(height: AppSizes.l),
            const Text('Способ доставки', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSizes.s),
            Row(
              children: [
                for (final DeliveryMethod method in DeliveryMethod.values) ...[
                  Expanded(
                    child: _DeliveryOption(
                      method: method,
                      isSelected: method == _deliveryMethod,
                      onTap: () => setState(() => _deliveryMethod = method),
                    ),
                  ),
                  if (method != DeliveryMethod.values.last)
                    const SizedBox(width: AppSizes.s),
                ],
              ],
            ),
            const SizedBox(height: AppSizes.m),
            if (_deliveryMethod == DeliveryMethod.courier)
              AppTextField(
                label: 'Адрес доставки',
                hint: 'Город, улица, дом, квартира',
                controller: _address,
                maxLength: 150,
                validator: _validateAddress,
              )
            else
              const AppCard(
                child: Row(
                  children: [
                    Icon(Icons.storefront_outlined),
                    SizedBox(width: AppSizes.m),
                    Expanded(
                      child: Text(_pickupPoint, style: AppTextStyles.bodySecondary),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSizes.l),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ваш заказ', style: AppTextStyles.sectionTitle),
                  const SizedBox(height: AppSizes.s),
                  for (final CartItem item in cart.items)
                    SummaryRow(
                      label: '${item.product.name}'
                          '${item.selectedSize == null ? '' : ', ${ItemOptions.decode(item.selectedSize).label}'}'
                          ' × ${item.quantity}',
                      value: Formatters.price(item.total),
                    ),
                  const Divider(),
                  SummaryRow(
                    label: 'Товары',
                    value: Formatters.price(cart.itemsTotal),
                  ),
                  SummaryRow(
                    label: 'Доставка',
                    value: delivery == 0 ? 'Бесплатно' : Formatters.price(delivery),
                  ),
                  SummaryRow(
                    label: 'Итого',
                    value: Formatters.price(cart.itemsTotal + delivery),
                    isTotal: true,
                  ),
                  const SizedBox(height: AppSizes.xs),
                  const Text(
                    'Оплата наличными или картой при получении',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryOption extends StatelessWidget {
  const _DeliveryOption({
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  final DeliveryMethod method;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double price = OrderState.deliveryPrice(method);
    final Color foreground =
        isSelected ? AppColors.textOnDark : AppColors.textPrimary;
    return Material(
      color: isSelected ? AppColors.black : AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.m),
          child: Column(
            children: [
              Icon(
                method == DeliveryMethod.courier
                    ? Icons.local_shipping_outlined
                    : Icons.storefront_outlined,
                color: foreground,
              ),
              const SizedBox(height: AppSizes.xs),
              Text(method.label, style: AppTextStyles.body.copyWith(color: foreground)),
              Text(
                price == 0 ? 'Бесплатно' : Formatters.price(price),
                style: AppTextStyles.caption.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
