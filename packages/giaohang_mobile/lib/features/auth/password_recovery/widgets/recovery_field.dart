import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../screens/widgets/auth_strings.dart';

class RecoveryField extends StatefulWidget {
  const RecoveryField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.validator,
    required this.enabled,
    this.password = false,
    this.code = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final FormFieldValidator<String> validator;
  final bool enabled;
  final bool password;
  final bool code;
  final ValueChanged<String>? onSubmitted;

  @override
  State<RecoveryField> createState() => _RecoveryFieldState();
}

class _RecoveryFieldState extends State<RecoveryField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    enabled: widget.enabled,
    validator: widget.validator,
    onFieldSubmitted: widget.onSubmitted,
    obscureText: widget.password && _obscure,
    autocorrect: false,
    enableSuggestions: false,
    keyboardType: widget.code
        ? TextInputType.number
        : widget.password
        ? TextInputType.visiblePassword
        : TextInputType.emailAddress,
    textInputAction: widget.onSubmitted == null
        ? TextInputAction.next
        : TextInputAction.done,
    autofillHints: widget.code
        ? const [AutofillHints.oneTimeCode]
        : widget.password
        ? const [AutofillHints.newPassword]
        : const [AutofillHints.email],
    inputFormatters: widget.code
        ? [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ]
        : null,
    textAlign: widget.code ? TextAlign.center : TextAlign.start,
    style: widget.code
        ? AppTextStyles.displayMedium.copyWith(
            color: AppColors.primary,
            letterSpacing: AppSpacing.sm,
          )
        : AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
    cursorColor: AppColors.primary,
    decoration: InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: AppTextStyles.labelLarge.copyWith(
        color: AppColors.textSecondary,
      ),
      hintStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textSecondary,
        letterSpacing: 0,
      ),
      filled: true,
      fillColor: AppColors.bgLight,
      contentPadding: const EdgeInsets.all(AppSpacing.lg),
      errorMaxLines: 3,
      errorStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
      border: const OutlineInputBorder(
        borderRadius: AppRadius.lg,
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.lg,
        borderSide: BorderSide(color: AppColors.border),
      ),
      disabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.lg,
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.lg,
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.lg,
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.lg,
        borderSide: BorderSide(color: AppColors.error, width: 1.5),
      ),
      suffixIcon: widget.password
          ? IconButton(
              tooltip: _obscure
                  ? AuthStrings.showPassword
                  : AuthStrings.hidePassword,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: widget.enabled
                  ? () => setState(() => _obscure = !_obscure)
                  : null,
              color: AppColors.textSecondary,
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
              ),
            )
          : null,
    ),
  );
}
