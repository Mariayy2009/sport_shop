import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/errors/app_exception.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../core/utils/validators.dart';
import '../../models/user.dart';
import '../../state/auth_state.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/labeled_checkbox.dart';

/// Экран «Вход» (фрейм Figma «вход»).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _rememberMe = true;
  bool _wasSubmitted = false;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _wasSubmitted = true);

    final bool isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      AppMessages.showError(context, AppStrings.fixFormErrors);
      return;
    }

    try {
      final User user = await context.read<AuthState>().login(
            email: _emailController.text,
            password: _passwordController.text,
            rememberMe: _rememberMe,
          );
      if (!mounted) return;
      AppMessages.showSuccess(context, 'Добро пожаловать, ${user.greetingName}!');
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.main, (route) => false);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.field == 'email') {
          _emailError = error.message;
        } else if (error.field == 'password') {
          _passwordError = error.message;
        }
      });
      AppMessages.showError(context, error.message);
    } catch (error) {
      debugPrint('Ошибка входа: $error');
      if (!mounted) return;
      AppMessages.showError(context, AppStrings.unexpectedError);
    }
  }

  void _showForgotPassword() {
    AppMessages.showInfoDialog(
      context,
      title: AppStrings.forgotPasswordTitle,
      message: AppStrings.forgotPasswordMessage,
    );
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
            vertical: AppSizes.xxl,
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
                  const SizedBox(height: AppSizes.xxl),
                  const Text(
                    AppStrings.loginTitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.screenTitle,
                  ),
                  const SizedBox(height: AppSizes.xxl),
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
                    label: AppStrings.passwordLabel,
                    controller: _passwordController,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    validator: Validators.loginPassword,
                    forceErrorText: _passwordError,
                    onChanged: (_) {
                      if (_passwordError != null) {
                        setState(() => _passwordError = null);
                      }
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: AppSizes.s),
                  Row(
                    children: [
                      Expanded(
                        child: LabeledCheckbox(
                          value: _rememberMe,
                          label: AppStrings.rememberMe,
                          onChanged: (value) =>
                              setState(() => _rememberMe = value),
                        ),
                      ),
                      TextButton(
                        onPressed: _showForgotPassword,
                        child: const Text(AppStrings.forgotPassword),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.l),
                  CustomButton(
                    text: AppStrings.loginButton,
                    isLoading: isLoading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSizes.m),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        AppStrings.noAccount,
                        style: AppTextStyles.bodySecondary,
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context)
                            .pushNamed(AppRoutes.registration),
                        child: const Text(AppStrings.registrationLink),
                      ),
                    ],
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
