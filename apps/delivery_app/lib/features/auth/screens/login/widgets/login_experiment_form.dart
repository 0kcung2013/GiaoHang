import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../widgets/auth_strings.dart';
import 'login_experiment_components.dart';
import 'login_experiment_tokens.dart';

class LoginExperimentFormSurface extends StatelessWidget {
  const LoginExperimentFormSurface({
    super.key,
    required this.isWide,
    required this.compactVertical,
    required this.hideSecondaryActions,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isBusy,
    required this.obscurePassword,
    required this.emailValidator,
    required this.passwordValidator,
    required this.onEmailSignIn,
    required this.onGoogleSignIn,
    required this.onTogglePassword,
    required this.onRegister,
    required this.onPasswordSubmitted,
    this.errorMessage,
  });

  final bool isWide;
  final bool compactVertical;
  final bool hideSecondaryActions;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isBusy;
  final bool obscurePassword;
  final String? errorMessage;
  final FormFieldValidator<String> emailValidator;
  final FormFieldValidator<String> passwordValidator;
  final VoidCallback onEmailSignIn;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onTogglePassword;
  final VoidCallback onRegister;
  final ValueChanged<String> onPasswordSubmitted;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 420;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? AppSpacing.xl2 : AppSpacing.xl3,
        compactVertical
            ? AppSpacing.xl
            : isWide
            ? AppSpacing.xl5
            : AppSpacing.xl2,
        compact ? AppSpacing.xl2 : AppSpacing.xl3,
        compactVertical
            ? AppSpacing.lg
            : isWide
            ? AppSpacing.xl4
            : AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: LoginExperimentTokens.surface,
        borderRadius: isWide
            ? BorderRadius.zero
            : LoginExperimentTokens.mobileSheetRadius,
        boxShadow: isWide ? null : LoginExperimentTokens.sheetShadow,
      ),
      child: AutofillGroup(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AuthStrings.loginTitle,
                style: AppTextStyles.displayMedium.copyWith(
                  color: LoginExperimentTokens.ink,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                  letterSpacing: -0.7,
                ),
              ),
              AnimatedSize(
                duration: AppDuration.fast,
                curve: AppCurve.decelerate,
                alignment: Alignment.topLeft,
                child: hideSecondaryActions
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: compactVertical
                                ? AppSpacing.xs
                                : AppSpacing.sm,
                          ),
                          Text(
                            AuthStrings.loginSubtitle,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: LoginExperimentTokens.muted,
                            ),
                          ),
                        ],
                      ),
              ),
              SizedBox(height: compactVertical ? AppSpacing.md : AppSpacing.xl),
              LoginExperimentField(
                controller: emailController,
                label: AuthStrings.email,
                hint: AuthStrings.emailPlaceholder,
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: emailValidator,
              ),
              SizedBox(height: compactVertical ? AppSpacing.sm : AppSpacing.md),
              LoginExperimentField(
                controller: passwordController,
                label: AuthStrings.password,
                hint: AuthStrings.passwordPlaceholder,
                icon: Icons.lock_outline_rounded,
                textInputAction: TextInputAction.done,
                obscureText: obscurePassword,
                autofillHints: const [AutofillHints.password],
                validator: passwordValidator,
                onSubmitted: onPasswordSubmitted,
                suffixIcon: IconButton(
                  onPressed: onTogglePassword,
                  tooltip: obscurePassword
                      ? AuthStrings.showPassword
                      : AuthStrings.hidePassword,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: AnimatedSwitcher(
                    duration: AppDuration.fast,
                    child: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      key: ValueKey(obscurePassword),
                      color: LoginExperimentTokens.muted,
                      size: 21,
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: AppDuration.normal,
                curve: AppCurve.decelerate,
                alignment: Alignment.topCenter,
                child: errorMessage == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: LoginExperimentError(
                          key: ValueKey(errorMessage),
                          message: errorMessage!,
                        ),
                      ),
              ),
              SizedBox(height: compactVertical ? AppSpacing.md : AppSpacing.xl),
              LoginExperimentPrimaryButton(
                isBusy: isBusy,
                onPressed: onEmailSignIn,
              ),
              if (!hideSecondaryActions) ...[
                SizedBox(
                  height: compactVertical ? AppSpacing.lg : AppSpacing.xl,
                ),
                const LoginExperimentDivider(),
                SizedBox(
                  height: compactVertical ? AppSpacing.sm : AppSpacing.md,
                ),
                LoginExperimentGoogleButton(
                  isBusy: isBusy,
                  onPressed: onGoogleSignIn,
                ),
                const SizedBox(height: AppSpacing.xs),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${AuthStrings.noAccount} ',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: LoginExperimentTokens.muted,
                        ),
                      ),
                      TextButton(
                        onPressed: isBusy ? null : onRegister,
                        style: TextButton.styleFrom(
                          foregroundColor: LoginExperimentTokens.accent,
                          minimumSize: const Size(48, 48),
                          textStyle: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text(AuthStrings.registerNow),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
