import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../password_recovery_controller.dart';
import '../password_recovery_strings.dart';
import '../utils/password_recovery_validation.dart';
import 'recovery_field.dart';

class RecoveryForm extends StatelessWidget {
  const RecoveryForm({
    super.key,
    required this.step,
    required this.formKey,
    required this.email,
    required this.code,
    required this.password,
    required this.confirm,
    required this.busy,
    required this.onSubmit,
  });

  final PasswordRecoveryStep step;
  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController code;
  final TextEditingController password;
  final TextEditingController confirm;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: AutofillGroup(
      onDisposeAction: AutofillContextAction.cancel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (step == PasswordRecoveryStep.email)
            RecoveryField(
              key: const ValueKey('recovery-email'),
              controller: email,
              label: PasswordRecoveryStrings.email,
              hint: PasswordRecoveryStrings.emailPlaceholder,
              validator: validateRecoveryEmail,
              enabled: !busy,
              onSubmitted: (_) => onSubmit(),
            ),
          if (step == PasswordRecoveryStep.code) ...[
            RecoveryField(
              key: const ValueKey('recovery-code'),
              controller: code,
              label: PasswordRecoveryStrings.code,
              hint: PasswordRecoveryStrings.codePlaceholder,
              validator: validateRecoveryCode,
              enabled: !busy,
              code: true,
              onSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              PasswordRecoveryStrings.deliveryNotice,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (step == PasswordRecoveryStep.password) ...[
            RecoveryField(
              key: const ValueKey('recovery-password'),
              controller: password,
              label: PasswordRecoveryStrings.newPassword,
              hint: PasswordRecoveryStrings.minimumPassword,
              validator: validateRecoveryPassword,
              enabled: !busy,
              password: true,
            ),
            const SizedBox(height: AppSpacing.xl2),
            RecoveryField(
              key: const ValueKey('recovery-confirm'),
              controller: confirm,
              label: PasswordRecoveryStrings.confirmPassword,
              hint: PasswordRecoveryStrings.confirmPassword,
              validator: (value) => value != password.text
                  ? PasswordRecoveryStrings.mismatch
                  : validateRecoveryPassword(value),
              enabled: !busy,
              password: true,
              onSubmitted: (_) => onSubmit(),
            ),
          ],
        ],
      ),
    ),
  );
}
