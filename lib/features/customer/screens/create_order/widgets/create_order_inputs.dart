import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/constants/app_theme.dart';

const createOrderSectionCardKey = Key('create-order-section-card');
const createOrderTextFieldKey = Key('create-order-text-field');

class CreateOrderSection extends StatelessWidget {
  const CreateOrderSection({
    super.key,
    required this.step,
    required this.icon,
    required this.title,
    this.subtitle,
    this.accentColor = AppColors.accent,
    required this.children,
  });

  final String step;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accentColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Container(
        key: createOrderSectionCardKey,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl,
          border: Border.all(color: AppColors.border.withValues(alpha: 0.82)),
          boxShadow: AppShadow.subtle,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: AppRadius.md,
                  ),
                  child: Icon(icon, size: 21, color: accentColor),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.headingSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: AppRadius.full,
                  ),
                  child: Text(
                    step,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            ...children,
          ],
        ),
      ),
    );
  }
}

class CreateOrderTextField extends StatefulWidget {
  const CreateOrderTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    this.helperText,
    this.autofillHints,
    this.inputFormatters,
    this.maxLength,
    this.requiredField = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;
  final String? helperText;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool requiredField;

  @override
  State<CreateOrderTextField> createState() => _CreateOrderTextFieldState();
}

class _CreateOrderTextFieldState extends State<CreateOrderTextField> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final isMultiline = widget.maxLines > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: AppTextStyles.labelMedium.copyWith(
                color: _hasFocus ? AppColors.accent : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (widget.requiredField) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(
                '•',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Focus(
          onFocusChange: (focused) => setState(() => _hasFocus = focused),
          child: TextFormField(
            key: createOrderTextFieldKey,
            controller: widget.controller,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            autofillHints: widget.autofillHints,
            cursorColor: AppColors.accent,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            inputFormatters: widget.inputFormatters,
            validator: widget.validator,
            textAlignVertical: isMultiline
                ? TextAlignVertical.top
                : TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: AnimatedContainer(
                  duration: AppDuration.fast,
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _hasFocus ? AppColors.accentLight : AppColors.bgCard,
                    borderRadius: AppRadius.md,
                    border: Border.all(
                      color: _hasFocus
                          ? AppColors.accent.withValues(alpha: 0.2)
                          : AppColors.border,
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    color: _hasFocus
                        ? AppColors.accent
                        : AppColors.textSecondary,
                    size: 19,
                  ),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 58,
                minHeight: 56,
              ),
              suffixIcon: widget.suffixIcon,
              helperText: widget.helperText,
              counterText: widget.maxLength == null ? null : '',
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
              helperStyle: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              filled: true,
              fillColor: AppColors.bgLight,
              border: _inputBorder(AppColors.border),
              enabledBorder: _inputBorder(AppColors.border),
              focusedBorder: _inputBorder(AppColors.accent, width: 1.5),
              errorBorder: _inputBorder(AppColors.error),
              focusedErrorBorder: _inputBorder(AppColors.error, width: 1.5),
              contentPadding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                isMultiline ? AppSpacing.md : AppSpacing.lg,
                AppSpacing.lg,
                isMultiline ? AppSpacing.md : AppSpacing.lg,
              ),
              errorStyle: AppTextStyles.bodySmall.copyWith(
                color: AppColors.error,
              ),
              errorMaxLines: 2,
            ),
          ),
        ),
      ],
    );
  }
}

OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: AppRadius.lg,
    borderSide: BorderSide(color: color, width: width),
  );
}
