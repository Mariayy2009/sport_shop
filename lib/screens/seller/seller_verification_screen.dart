import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/legal/legal_documents.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../core/utils/validators.dart';
import '../../data/repositories/moderation_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../models/user.dart';
import '../../state/auth_state.dart';
import '../../state/seller_badge_state.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/labeled_checkbox.dart';

/// Данные продавца и согласие с правилами. Без них нельзя выставлять
/// товары: так площадка знает, кто продаёт, и при нарушении закона
/// может передать сведения в правоохранительные органы.
///
/// [openShop] — покупатель открывает магазин (нужно ещё название).
class SellerVerificationScreen extends StatefulWidget {
  const SellerVerificationScreen({super.key, this.openShop = false});

  final bool openShop;

  @override
  State<SellerVerificationScreen> createState() => _SellerVerificationScreenState();
}

class _SellerVerificationScreenState extends State<SellerVerificationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _shop = TextEditingController();
  final TextEditingController _iin = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _address = TextEditingController();
  String _form = SellerLegal.forms.first;
  bool _rules = false, _goods = false, _police = false;
  bool _showErrors = false, _saving = false;

  @override
  void initState() {
    super.initState();
    final User? user = context.read<AuthState>().currentUser;
    _phone.text = user?.phone ?? '';
    _name.text = user?.fullName ?? '';
    if (!widget.openShop && user?.id != null) _loadExisting(user!.id!);
  }

  Future<void> _loadExisting(int id) async {
    final SellerLegal legal = await context.read<ModerationRepository>().legalOf(id);
    if (!mounted) return;
    setState(() {
      _form = legal.legalForm ?? _form;
      _iin.text = legal.iin ?? '';
      _name.text = legal.legalName ?? _name.text;
      _phone.text = legal.phone ?? _phone.text;
      _address.text = legal.address ?? '';
    });
  }

  @override
  void dispose() {
    for (final c in [_shop, _iin, _name, _phone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _showErrors = true);
    final bool formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk || !_rules || !_goods || !_police) {
      AppMessages.showWarning(
        context,
        formOk ? 'Отметьте все согласия — без них торговать нельзя' : 'Проверьте данные',
      );
      return;
    }
    final ModerationRepository moderation = context.read<ModerationRepository>();
    final UserRepository users = context.read<UserRepository>();
    final AuthState auth = context.read<AuthState>();
    final SellerBadgeState badges = context.read<SellerBadgeState>();
    final NavigatorState navigator = Navigator.of(context);
    final int userId = auth.currentUser!.id!;
    final SellerLegal legal = SellerLegal(
      legalForm: _form,
      iin: _iin.text.trim(),
      legalName: _name.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      agreedAt: DateTime.now(),
      rulesVersion: LegalDoc.version,
    );
    setState(() => _saving = true);
    try {
      if (widget.openShop) {
        await moderation.openShop(userId, _shop.text, legal);
        // Роль продавца появляется вместе с магазином — перечитываем профиль.
        final User? updated = await users.findById(userId);
        if (updated != null) auth.updateCurrentUser(updated);
      } else {
        await moderation.saveLegal(userId, legal);
        await badges.refresh();
      }
      if (!mounted) return;
      AppMessages.showSuccess(
        context,
        widget.openShop
            ? 'Магазин открыт! Теперь можно выставлять товары в «Кабинете»'
            : 'Данные продавца сохранены — можно выставлять товары',
      );
      navigator.pop(true);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppMessages.showError(context, error.message);
    }
  }

  Widget _doc(LegalDoc doc) => TextButton(
        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.legal, arguments: doc),
        child: Text(doc.title),
      );

  @override
  Widget build(BuildContext context) {
    final bool bin = _form == 'ТОО';
    return AppScaffold(
      title: widget.openShop ? 'Открыть магазин' : 'Данные продавца',
      navTab: MainTab.profile,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          children: [
            const Text(
              'Площадка должна знать, кто продаёт товар: эти данные видит только '
              'администрация. Покупатели видят название магазина.',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: AppSizes.m),
            if (widget.openShop) ...[
              AppTextField(
                label: 'Название магазина',
                controller: _shop,
                maxLength: 40,
                validator: (v) =>
                    (v?.trim().length ?? 0) < 2 ? 'Введите название магазина' : null,
              ),
              const SizedBox(height: AppSizes.m),
            ],
            const Text('Форма деятельности', style: AppTextStyles.fieldLabel),
            const SizedBox(height: AppSizes.xs),
            Wrap(
              spacing: AppSizes.s,
              children: [
                for (final String form in SellerLegal.forms)
                  ChoiceChip(
                    label: Text(form),
                    selected: form == _form,
                    selectedColor: AppColors.black,
                    labelStyle: TextStyle(
                      color: form == _form ? AppColors.white : AppColors.textPrimary,
                    ),
                    onSelected: (_) => setState(() => _form = form),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.m),
            AppTextField(
              label: bin ? 'БИН организации' : 'ИИН',
              hint: '12 цифр',
              controller: _iin,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 12,
              validator: (v) => Validators.iin(v, bin: bin),
            ),
            const SizedBox(height: AppSizes.m),
            AppTextField(
              label: bin ? 'Наименование организации' : 'ФИО полностью',
              controller: _name,
              maxLength: 120,
              validator: (v) => (v?.trim().length ?? 0) < 5
                  ? (bin ? 'Введите наименование' : 'Введите фамилию, имя и отчество')
                  : null,
            ),
            const SizedBox(height: AppSizes.m),
            AppTextField(
              label: 'Контактный телефон',
              controller: _phone,
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
            ),
            const SizedBox(height: AppSizes.m),
            AppTextField(
              label: 'Юридический адрес',
              hint: 'Город, улица, дом',
              controller: _address,
              maxLength: 200,
              validator: (v) =>
                  (v?.trim().length ?? 0) < 10 ? 'Укажите город, улицу и дом' : null,
            ),
            const SizedBox(height: AppSizes.m),
            Wrap(children: [_doc(LegalDoc.sellerRules), _doc(LegalDoc.terms), _doc(LegalDoc.privacy)]),
            LabeledCheckbox(
              value: _rules,
              hasError: _showErrors && !_rules,
              label: 'Я прочитал(а) Правила для продавцов и Пользовательское соглашение '
                  'и принимаю их',
              onChanged: (v) => setState(() => _rules = v),
            ),
            LabeledCheckbox(
              value: _goods,
              hasError: _showErrors && !_goods,
              label: 'Продаю только разрешённые товары; спортивное питание и товары, '
                  'требующие сертификации, имеют сертификаты соответствия',
              onChanged: (v) => setState(() => _goods = v),
            ),
            LabeledCheckbox(
              value: _police,
              hasError: _showErrors && !_police,
              label: 'Согласен(на): при выявлении признаков преступления мои данные и '
                  'материалы о товарах будут переданы в правоохранительные органы',
              onChanged: (v) => setState(() => _police = v),
            ),
            const SizedBox(height: AppSizes.l),
            CustomButton(
              text: widget.openShop ? 'Открыть магазин' : 'Сохранить',
              isLoading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
