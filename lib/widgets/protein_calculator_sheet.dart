import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';
import '../models/product.dart';
import '../state/profile_state.dart';
import 'dark_pill.dart';

/// Цель тренировок и сколько белка нужно на килограмм веса в день.
enum ProteinGoal {
  keep('Поддержание формы', 1.2),
  lose('Похудение', 1.6),
  gain('Набор мышц', 1.8);

  const ProteinGoal(this.label, this.gramsPerKg);

  final String label;
  final double gramsPerKg;
}

/// Расчёт порций протеина: суточная норма белка по весу (из анкеты
/// профиля), из неё ~2/3 обычно дают продукты, остальное можно добрать
/// протеином. Ориентир, а не совет врача.
class ProteinPlan {
  const ProteinPlan({
    required this.dailyProtein,
    required this.fromShake,
    required this.portions,
    this.days,
  });

  final int dailyProtein;
  final int fromShake;
  final double portions;

  /// На сколько дней хватит упаковки (если вес указан в названии).
  final int? days;

  static ProteinPlan of(Product product, int weight, ProteinGoal goal) {
    final (int portionGrams, int proteinPerPortion) = product.proteinPortion!;
    final int daily = (weight * goal.gramsPerKg).round();
    final int shake = (daily / 3).round();
    // Половинки порции — удобно отмерять ложкой.
    final double portions =
        ((shake / proteinPerPortion) * 2).round().clamp(1, 6) / 2;
    final RegExpMatch? pack = RegExp(r'(\d+)\s*г').firstMatch(product.name);
    final int? days = pack == null
        ? null
        : (int.parse(pack.group(1)!) / (portions * portionGrams)).floor();
    return ProteinPlan(
      dailyProtein: daily,
      fromShake: shake,
      portions: portions,
      days: days,
    );
  }
}

class ProteinCalculatorSheet extends StatefulWidget {
  const ProteinCalculatorSheet({super.key, required this.product});

  final Product product;

  static Future<void> show(BuildContext context, Product product) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => ProteinCalculatorSheet(product: product),
      );

  @override
  State<ProteinCalculatorSheet> createState() => _ProteinCalculatorSheetState();
}

class _ProteinCalculatorSheetState extends State<ProteinCalculatorSheet> {
  late final TextEditingController _weight = TextEditingController(
    text: '${context.read<ProfileState>().sizes?.weight ?? 70}',
  );
  ProteinGoal _goal = ProteinGoal.keep;

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  String _portions(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : value.toString().replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final int? weight = int.tryParse(_weight.text);
    final bool valid = weight != null && weight >= 30 && weight <= 200;
    final ProteinPlan? plan =
        valid ? ProteinPlan.of(widget.product, weight, _goal) : null;
    final (int portionGrams, int protein) = widget.product.proteinPortion!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        0,
        AppSizes.screenPadding,
        AppSizes.l + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Сколько порций в день', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSizes.xs),
          Text(
            'Порция $portionGrams г — $protein г белка',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: AppSizes.m),
          TextField(
            controller: _weight,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Ваш вес, кг',
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSizes.m),
          Wrap(
            spacing: AppSizes.s,
            runSpacing: AppSizes.s,
            children: [
              for (final ProteinGoal goal in ProteinGoal.values)
                DarkPill(
                  label: goal.label,
                  selected: goal == _goal,
                  onTap: () => setState(() => _goal = goal),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.l),
          if (plan == null)
            Text(
              'Укажите вес от 30 до 200 кг',
              style: AppTextStyles.body.copyWith(color: AppColors.error),
            )
          else ...[
            Text(
              '${_portions(plan.portions)} '
              '${plan.portions <= 1 ? 'порция' : plan.portions < 5 ? 'порции' : 'порций'} в день',
              style: AppTextStyles.priceLarge,
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              'Норма белка — около ${plan.dailyProtein} г в день '
              '(${_goal.gramsPerKg} г на кг). Обычно две трети дают мясо, '
              'рыба, яйца, творог, а ~${plan.fromShake} г удобно добрать протеином.'
              '${plan.days == null ? '' : ' Упаковки хватит примерно на ${plan.days} дней.'}',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSizes.s),
            const Text(
              'Это ориентир для здорового взрослого. При болезнях почек '
              'и для подростков — сначала посоветуйтесь с врачом.',
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }
}
