import 'dart:async';

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';

/// Строка поиска из Figma: белая «таблетка» с лупой справа.
/// При [searchOnType] поиск запускается через 400 мс после ввода.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.onSearch,
    this.initialValue = '',
    this.hint = 'Поиск товаров',
    this.searchOnType = false,
  });

  final ValueChanged<String> onSearch;
  final String initialValue;
  final String hint;
  final bool searchOnType;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  Timer? _debounce;

  @override
  void didUpdateWidget(SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Поиск изменили извне (например, с главной) — показываем новый текст.
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {}); // обновить иконку очистки
    if (!widget.searchOnType) return;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => widget.onSearch(value.trim()),
    );
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {});
    widget.onSearch('');
  }

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onChanged: _onChanged,
      onSubmitted: (value) {
        _debounce?.cancel();
        widget.onSearch(value.trim());
      },
      maxLength: 50,
      style: AppTextStyles.body,
      cursorColor: AppColors.black,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
        counterText: '',
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.l,
          vertical: AppSizes.m,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.black),
        ),
        suffixIcon: _controller.text.isEmpty
            ? const Icon(Icons.search, color: AppColors.textPrimary)
            : IconButton(
                tooltip: 'Очистить',
                onPressed: _clear,
                icon: const Icon(Icons.close, color: AppColors.textPrimary),
              ),
      ),
    );
  }
}
