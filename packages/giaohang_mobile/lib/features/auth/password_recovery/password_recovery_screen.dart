import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../screens/widgets/account_support_contact.dart';
import '../screens/widgets/auth_form_components.dart';
import '../screens/widgets/auth_strings.dart';
import 'data/password_recovery_service.dart';
import 'password_recovery_controller.dart';
import 'password_recovery_strings.dart';
import 'widgets/recovery_form.dart';
import 'widgets/recovery_header.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({
    super.key,
    this.initialEmail = '',
    this.gateway,
  });
  final String initialEmail;
  final PasswordRecoveryGateway? gateway;

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  late final _controller = PasswordRecoveryController(
    gateway: widget.gateway ?? PasswordRecoveryService(),
  );
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.busy) return;
    if (_controller.step == PasswordRecoveryStep.success) {
      Navigator.pop(context, _controller.email);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    switch (_controller.step) {
      case PasswordRecoveryStep.email:
        await _controller.sendCode(_email.text);
      case PasswordRecoveryStep.code:
        await _controller.verifyCode(_code.text);
      case PasswordRecoveryStep.password:
        await _controller.savePassword(_password.text);
      case PasswordRecoveryStep.success:
        break;
    }
    if (!mounted) return;
    if (_controller.step == PasswordRecoveryStep.password ||
        _controller.step == PasswordRecoveryStep.success) {
      _code.clear();
    }
    if (_controller.step != PasswordRecoveryStep.password) {
      _password.clear();
      _confirm.clear();
    }
  }

  Future<void> _resend() async {
    await _controller.sendCode(_controller.email);
    if (mounted && _controller.error == null) _code.clear();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: AppColors.bgCard,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: AppColors.bgCard,
        elevation: 0,
        leading: IconButton(
          tooltip: PasswordRecoveryStrings.back,
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
        ),
        title: Text(
          AuthStrings.appName,
          style: AppTextStyles.headingSmall.copyWith(color: AppColors.primary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final step = _controller.step;
                final success = step == PasswordRecoveryStep.success;
                final (label, busyLabel) = switch (step) {
                  PasswordRecoveryStep.email => (
                    _controller.resendSeconds > 0
                        ? PasswordRecoveryStrings.resendIn(
                            _controller.resendSeconds,
                          )
                        : PasswordRecoveryStrings.send,
                    PasswordRecoveryStrings.sending,
                  ),
                  PasswordRecoveryStep.code => (
                    PasswordRecoveryStrings.verify,
                    PasswordRecoveryStrings.verifying,
                  ),
                  PasswordRecoveryStep.password => (
                    PasswordRecoveryStrings.save,
                    PasswordRecoveryStrings.saving,
                  ),
                  PasswordRecoveryStep.success => (
                    PasswordRecoveryStrings.login,
                    PasswordRecoveryStrings.login,
                  ),
                };
                return SingleChildScrollView(
                  key: ValueKey(step),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl2,
                    AppSpacing.xl2,
                    AppSpacing.xl2,
                    AppSpacing.xl3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RecoveryHeader(step: step, email: _controller.email),
                      const SizedBox(height: AppSpacing.xl3),
                      if (!success)
                        RecoveryForm(
                          key: ValueKey(step),
                          step: step,
                          formKey: _formKey,
                          email: _email,
                          code: _code,
                          password: _password,
                          confirm: _confirm,
                          busy: _controller.busy,
                          onSubmit: _submit,
                        ),
                      if (_controller.error != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        AuthErrorBanner(message: _controller.error!),
                      ],
                      const SizedBox(height: AppSpacing.xl2),
                      FilledButton.icon(
                        key: const ValueKey('recovery-submit'),
                        onPressed:
                            _controller.busy ||
                                (step == PasswordRecoveryStep.email &&
                                    _controller.resendSeconds > 0)
                            ? null
                            : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.accentLight,
                          disabledForegroundColor: AppColors.textSecondary,
                          minimumSize: const Size.fromHeight(56),
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.lg,
                          ),
                          textStyle: AppTextStyles.labelLarge,
                        ),
                        icon: Icon(
                          _controller.busy
                              ? Icons.hourglass_top_rounded
                              : success
                              ? Icons.login_rounded
                              : Icons.arrow_forward_rounded,
                          size: 20,
                        ),
                        label: Text(
                          _controller.busy ? busyLabel : label,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (step == PasswordRecoveryStep.code) ...[
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            minimumSize: const Size(48, 48),
                            textStyle: AppTextStyles.labelMedium,
                          ),
                          onPressed:
                              _controller.busy || _controller.resendSeconds > 0
                              ? null
                              : _resend,
                          child: Text(
                            _controller.resendSeconds > 0
                                ? PasswordRecoveryStrings.resendIn(
                                    _controller.resendSeconds,
                                  )
                                : PasswordRecoveryStrings.resend,
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            minimumSize: const Size(48, 48),
                            textStyle: AppTextStyles.labelMedium,
                          ),
                          onPressed: _controller.busy
                              ? null
                              : () {
                                  _code.clear();
                                  _controller.changeEmail();
                                },
                          child: const Text(
                            PasswordRecoveryStrings.changeEmail,
                          ),
                        ),
                      ],
                      if (!success) ...[
                        const SizedBox(height: AppSpacing.xl2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                PasswordRecoveryStrings.securityNote,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const AccountSupportContact(
                          emailSubject: PasswordRecoveryStrings.supportSubject,
                          emailBody: PasswordRecoveryStrings.supportBody,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
