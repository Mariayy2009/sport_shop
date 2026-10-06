import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../models/order.dart';
import '../../widgets/app_header.dart';
import '../../widgets/custom_button.dart';

/// «Заказ оформлен!» (фрейм Figma «заказ2»).
class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key, required this.order});

  final Order order;

  void _goTo(BuildContext context, MainTab tab) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.main,
      (route) => false,
      arguments: tab,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Кнопка «назад» ведёт на главную, а не на пустое оформление.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goTo(context, MainTab.home);
      },
      child: Scaffold(
        appBar: const AppHeader(),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: const BoxDecoration(
                      color: AppColors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: AppColors.white, size: 56),
                  ),
                ),
                const SizedBox(height: AppSizes.xl),
                const Text(
                  'Заказ оформлен!',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.screenTitle,
                ),
                const SizedBox(height: AppSizes.s),
                Text(
                  'Номер заказа: ${Formatters.orderNumber(order.id ?? 0)}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.sectionTitle,
                ),
                const SizedBox(height: AppSizes.s),
                Text(
                  '${Formatters.itemsCount(order.itemsCount)} на сумму '
                  '${Formatters.price(order.totalPrice)}\n'
                  '${order.deliveryMethod == DeliveryMethod.courier ? 'Курьер свяжется с вами для согласования времени доставки' : 'Мы сообщим, когда заказ будет готов к выдаче'}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySecondary,
                ),
                const Spacer(),
                CustomButton(
                  text: 'История заказов',
                  variant: ButtonVariant.secondary,
                  onPressed: () {
                    final NavigatorState navigator = Navigator.of(context);
                    navigator.pushNamedAndRemoveUntil(
                      AppRoutes.main,
                      (route) => false,
                      arguments: MainTab.profile,
                    );
                    navigator.pushNamed(AppRoutes.orderHistory);
                  },
                ),
                const SizedBox(height: AppSizes.m),
                CustomButton(
                  text: 'На главную',
                  onPressed: () => _goTo(context, MainTab.home),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
