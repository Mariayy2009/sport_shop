import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/errors/app_exception.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../core/utils/validators.dart';
import '../../models/user.dart';
import '../../state/auth_state.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/labeled_checkbox.dart';

/// Экран «Регистрация» (фрейм Figma «регистрация»).
/// Поле «Surname» добавлено к макету: фамилия есть в таблице users.
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _isAgreed = false;
  bool _showAgreementError = false;
  bool _wasSubmitted = false;
  String? _emailError;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _wasSubmitted = true;
      _showAgreementError = !_isAgreed;
    });

    final bool isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      AppMessages.showError(context, AppStrings.fixFormErrors);
      return;
    }
    if (!_isAgreed) {
      AppMessages.showWarning(context, AppStrings.agreementRequired);
      return;
    }

    try {
      final User user = await context.read<AuthState>().register(
            firstName: _firstNameController.text,
            lastName: _lastNameController.text,
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (!mounted) return;
      AppMessages.showSuccess(
        context,
        'Аккаунт создан. Добро пожаловать, ${user.greetingName}!',
      );
      // Сценарий 1: после регистрации — в профиль.
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.main,
        (route) => false,
        arguments: MainTab.profile,
      );
    } on AppException catch (error) {
      if (!mounted) return;
      if (error.field == 'email') {
        setState(() => _emailError = error.message);
      }
      AppMessages.showError(context, error.message);
    } catch (error) {
      debugPrint('Ошибка регистрации: $error');
      if (!mounted) return;
      AppMessages.showError(context, AppStrings.unexpectedError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading = context.watch<AuthState>().isLoading;

    return Scaffold(
      appBar: AppHeader(
        showActions: false,
        showBackButton: Navigator.of(context).canPop(),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.xl,
            vertical: AppSizes.xl,
          ),
          child: Form(
            key: _formKey,
            autovalidateMode: _wasSubmitted
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSizes.l),
                  const Text(
                    AppStrings.registrationTitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.screenTitle,
                  ),
                  const SizedBox(height: AppSizes.xl),
                  AppTextField(
                    label: AppStrings.firstNameLabel,
                    controller: _firstNameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.givenName],
                    maxLength: Validators.nameMaxLength,
                    validator: (value) =>
                        Validators.name(value, emptyMessage: 'Введите имя'),
                  ),
                  const SizedBox(height: AppSizes.m),
                  AppTextField(
                    label: AppStrings.lastNameLabel,
                    controller: _lastNameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.familyName],
                    maxLength: Validators.nameMaxLength,
                    validator: (value) =>
                        Validators.name(value, emptyMessage: 'Введите фамилию'),
                  ),
                  const SizedBox(height: AppSizes.m),
                  AppTextField(
                    label: AppStrings.emailLabel,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    maxLength: Validators.emailMaxLength,
                    validator: Validators.email,
                    forceErrorText: _emailError,
                    onChanged: (_) {
                      if (_emailError != null) {
                        setState(() => _emailError = null);
                      }
                    },
                  ),
                  const SizedBox(height: AppSizes.m),
                  AppPasswordField(
                    label: AppStrings.registrationPasswordLabel,
                    controller: _passwordController,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: Validators.password,
                  ),
                  const SizedBox(height: AppSizes.m),
                  AppPasswordField(
                    label: AppStrings.confirmPasswordLabel,
                    controller: _confirmController,
                    textInputAction: TextInputAction.done,
                    validator: (value) => Validators.confirmPassword(
                      value,
                      _passwordController.text,
                    ),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: AppSizes.m),
                  LabeledCheckbox(
                    value: _isAgreed,
                    label: AppStrings.agreement,
                    hasError: _showAgreementError,
                    onChanged: (value) => setState(() {
                      _isAgreed = value;
                      if (value) _showAgreementError = false;
                    }),
                  ),
                  const SizedBox(height: AppSizes.l),
                  CustomButton(
                    text: AppStrings.registrationButton,
                    isLoading: isLoading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
