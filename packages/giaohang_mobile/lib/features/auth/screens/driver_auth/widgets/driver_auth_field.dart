import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../driver_auth_strings.dart';

InputDecoration driverInputDecoration({
  required String hint,
  IconData? icon,
  Widget? suffix,
  String? error,
}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: AppRadius.md,
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
    filled: true,
    fillColor: AppColors.bgLight,
    prefixIcon: icon == null
        ? null
        : Icon(icon, size: 20, color: AppColors.textSecondary),
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.all(AppSpacing.lg),
    border: border(AppColors.border),
    enabledBorder: border(AppColors.border),
    focusedBorder: border(AppColors.borderFocus),
    errorBorder: border(AppColors.error),
    focusedErrorBorder: border(AppColors.error),
    errorText: error,
    errorMaxLines: 3,
    errorStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
  );
}

/// Persistent label, keyboard behavior and password visibility for driver forms.
class DriverAuthField extends StatefulWidget {
  const DriverAuthField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.initialValue,
    this.icon,
    this.password = false,
    this.enabled = true,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.error,
    this.helper,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;
  final String? initialValue;
  final IconData? icon;
  final bool password;
  final bool enabled;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final String? error;
  final String? helper;

  @override
  State<DriverAuthField> createState() => _DriverAuthFieldState();
}

class _DriverAuthFieldState extends State<DriverAuthField> {
  bool _obscure = true;

  @override
  void didUpdateWidget(covariant DriverAuthField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.error != null && widget.error != oldWidget.error) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Scrollable.ensureVisible(context, alignment: 0.2);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        widget.label,
        style: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary),
      ),
      const SizedBox(height: AppSpacing.sm),
      TextFormField(
        controller: widget.controller,
        initialValue: widget.controller == null ? widget.initialValue : null,
        enabled: widget.enabled,
        keyboardType: widget.keyboardType,
        autofillHints: widget.autofillHints,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        obscureText: widget.password && _obscure,
        autocorrect:
            !widget.password &&
            widget.keyboardType != TextInputType.emailAddress,
        enableSuggestions: !widget.password,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        cursorColor: AppColors.primary,
        scrollPadding: const EdgeInsets.all(AppSpacing.xl2),
        decoration: driverInputDecoration(
          hint: widget.hint,
          icon: widget.icon,
          error: widget.error,
          suffix: widget.password
              ? IconButton(
                  tooltip: _obscure
                      ? DriverAuthStrings.showPassword
                      : DriverAuthStrings.hidePassword,
                  onPressed: widget.enabled
                      ? () => setState(() => _obscure = !_obscure)
                      : null,
                  color: AppColors.textSecondary,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20,
                  ),
                )
              : null,
        ),
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onSubmitted,
        validator: widget.validator,
      ),
      if (widget.helper != null) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(
          widget.helper!,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ],
  );
}
