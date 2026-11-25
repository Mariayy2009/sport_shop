import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';

/// Поле ввода из Figma: подпись сверху, белое скруглённое поле,
/// текст ошибки снизу.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.suffixIcon,
    this.forceErrorText,
    this.autofillHints,
    this.inputFormatters,
    this.maxLength,
    this.enabled = true,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final Widget? suffixIcon;

  /// Ошибка от сервиса (например, «Неверный пароль») — показывается под полем.
  final String? forceErrorText;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool enabled;

  /// Больше 1 — многострочное поле (состав, описание).
  final int maxLines;

  static OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Оформление поля из Figma — используется и выпадающими списками.
  static InputDecoration buildDecoration({String? hint, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSizes.l,
        vertical: AppSizes.m,
      ),
      counterText: '',
      suffixIcon: suffixIcon,
      errorStyle: AppTextStyles.fieldError,
      errorMaxLines: 2,
      border: _border(AppColors.border),
      enabledBorder: _border(AppColors.border),
      focusedBorder: _border(AppColors.black, width: 1.5),
      errorBorder: _border(AppColors.error),
      focusedErrorBorder: _border(AppColors.error, width: 1.5),
      disabledBorder: _border(AppColors.divider),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSizes.s, bottom: AppSizes.xs),
          child: Text(label, style: AppTextStyles.fieldLabel),
        ),
        TextFormField(
          controller: controller,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          obscureText: obscureText,
          forceErrorText: forceErrorText,
          autofillHints: autofillHints,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          maxLines: obscureText ? 1 : maxLines,
          minLines: 1,
          enabled: enabled,
          style: AppTextStyles.body,
          cursorColor: AppColors.black,
          decoration: buildDecoration(hint: hint, suffixIcon: suffixIcon),
        ),
      ],
    );
  }
}

/// Поле пароля с кнопкой «показать / скрыть».
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction,
    this.forceErrorText,
    this.autofillHints,
  });

  final String label;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction? textInputAction;
  final String? forceErrorText;
  final Iterable<String>? autofillHints;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _isObscured = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      controller: widget.controller,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      textInputAction: widget.textInputAction,
      forceErrorText: widget.forceErrorText,
      autofillHints: widget.autofillHints,
      keyboardType: TextInputType.visiblePassword,
      obscureText: _isObscured,
      maxLength: 64,
      suffixIcon: IconButton(
        tooltip: _isObscured ? 'Показать пароль' : 'Скрыть пароль',
        onPressed: () => setState(() => _isObscured = !_isObscured),
        icon: Icon(
          _isObscured
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: 20,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
