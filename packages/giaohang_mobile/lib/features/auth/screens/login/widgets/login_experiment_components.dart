import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../widgets/auth_strings.dart';
import 'google_mark.dart';
import 'login_experiment_tokens.dart';

class LoginExperimentField extends StatefulWidget {
  const LoginExperimentField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.iconColor,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.onSubmitted,
    this.autofillHints,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final Widget? suffixIcon;

  @override
  State<LoginExperimentField> createState() => _LoginExperimentFieldState();
}

class _LoginExperimentFieldState extends State<LoginExperimentField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;

    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      obscureText: widget.obscureText,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      autofillHints: widget.autofillHints,
      style: AppTextStyles.bodyMedium.copyWith(
        color: LoginExperimentTokens.ink,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        floatingLabelStyle: AppTextStyles.labelSmall.copyWith(
          color: LoginExperimentTokens.accent,
          fontWeight: FontWeight.w700,
        ),
        labelStyle: AppTextStyles.bodyMedium.copyWith(
          color: LoginExperimentTokens.muted,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: LoginExperimentTokens.muted.withValues(alpha: 0.72),
        ),
        prefixIcon: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: AnimatedContainer(
            duration: AppDuration.fast,
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: widget.iconColor.withValues(alpha: focused ? 0.17 : 0.10),
              borderRadius: AppRadius.sm,
            ),
            child: Icon(widget.icon, size: 20, color: widget.iconColor),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 54,
          minHeight: 58,
        ),
        suffixIcon: widget.suffixIcon,
        filled: true,
        fillColor: LoginExperimentTokens.field,
        contentPadding: const EdgeInsets.fromLTRB(0, 18, AppSpacing.lg, 18),
        enabledBorder: const OutlineInputBorder(
          borderRadius: LoginExperimentTokens.controlRadius,
          borderSide: BorderSide(color: Colors.transparent),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: LoginExperimentTokens.controlRadius,
          borderSide: BorderSide(
            color: LoginExperimentTokens.accent,
            width: 1.35,
          ),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: LoginExperimentTokens.controlRadius,
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: LoginExperimentTokens.controlRadius,
          borderSide: BorderSide(color: AppColors.error, width: 1.35),
        ),
        errorStyle: AppTextStyles.bodySmall.copyWith(
          color: AppColors.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class LoginExperimentError extends StatelessWidget {
  const LoginExperimentError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.07),
          borderRadius: AppRadius.md,
          border: Border.all(color: AppColors.error.withValues(alpha: 0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.11),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  message,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginExperimentPrimaryButton extends StatefulWidget {
  const LoginExperimentPrimaryButton({
    super.key,
    required this.isBusy,
    required this.onPressed,
  });

  final bool isBusy;
  final VoidCallback onPressed;

  @override
  State<LoginExperimentPrimaryButton> createState() =>
      _LoginExperimentPrimaryButtonState();
}

class _LoginExperimentPrimaryButtonState
    extends State<LoginExperimentPrimaryButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || widget.isBusy) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: AppDuration.fast,
        curve: AppCurve.decelerate,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadius.full,
            boxShadow: widget.isBusy
                ? AppShadow.subtle
                : LoginExperimentTokens.ctaShadow,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: widget.isBusy ? null : widget.onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: LoginExperimentTokens.accent,
                disabledBackgroundColor: LoginExperimentTokens.accent
                    .withValues(alpha: 0.56),
                foregroundColor: AppColors.textOnAccent,
                disabledForegroundColor: AppColors.textOnAccent,
                textStyle: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.full,
                ),
                elevation: 0,
              ),
              child: AnimatedSwitcher(
                duration: AppDuration.fast,
                switchInCurve: AppCurve.decelerate,
                switchOutCurve: AppCurve.accelerate,
                child: widget.isBusy
                    ? Row(
                        key: const ValueKey('login-busy'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textOnAccent,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(AuthStrings.loggingIn),
                        ],
                      )
                    : Row(
                        key: const ValueKey('login-idle'),
                        mainAxisSize: MainAxisSize.min,
                        children: [Text(AuthStrings.login)],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginExperimentGoogleButton extends StatelessWidget {
  const LoginExperimentGoogleButton({
    super.key,
    required this.isBusy,
    required this.onPressed,
  });

  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: LoginExperimentTokens.controlRadius,
        boxShadow: AppShadow.subtle,
      ),
      child: SizedBox(
        width: double.infinity,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: OutlinedButton(
            onPressed: isBusy ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: LoginExperimentTokens.ink,
              disabledForegroundColor: AppColors.textMuted,
              backgroundColor: LoginExperimentTokens.surface,
              side: const BorderSide(color: AppColors.border),
              textStyle: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: LoginExperimentTokens.controlRadius,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const GoogleMark(key: Key('login-google-icon')),
                const SizedBox(width: AppSpacing.md),
                const Flexible(
                  child: Text(
                    AuthStrings.loginWithGoogle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginExperimentDivider extends StatelessWidget {
  const LoginExperimentDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: LoginExperimentTokens.fieldBorder),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            AuthStrings.or,
            style: AppTextStyles.bodySmall.copyWith(
              color: LoginExperimentTokens.muted,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: LoginExperimentTokens.fieldBorder),
        ),
      ],
    );
  }
}
