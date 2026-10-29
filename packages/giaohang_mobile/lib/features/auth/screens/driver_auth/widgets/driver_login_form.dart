import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../driver_auth_strings.dart';
import 'driver_auth_field.dart';
import 'driver_auth_feedback.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/services/auth_service.dart';
import '../../widgets/auth_strings.dart';

class DriverLoginForm extends StatefulWidget {
  const DriverLoginForm({super.key});

  @override
  State<DriverLoginForm> createState() => _DriverLoginFormState();
}

class _DriverLoginFormState extends State<DriverLoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (!mounted) return;

      final role = await _authService.fetchUserRole();
      if (!mounted) return;

      final route = role == 'driver' ? '/driver-home' : '/unsupported-role';
      context.go(route);
    } on AuthException catch (e) {
      if (!mounted) return;
      String msg;
      if (e.code == 'user_banned') {
        msg = AuthStrings.accountDisabled;
      } else if (e.message.toLowerCase().contains('invalid')) {
        msg = DriverAuthStrings.invalidCredentials;
      } else {
        msg = '${DriverAuthStrings.loginFailed}: ${e.message}';
      }
      setState(() => _errorMessage = msg);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = DriverAuthStrings.connectionError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          constraints.maxHeight > 560 ? AppSpacing.xl5 : AppSpacing.lg,
          AppSpacing.screenH,
          AppSpacing.xl2,
        ),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  DriverAuthStrings.loginTitle,
                  style: AppTextStyles.displayMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl2),
                DriverAuthField(
                  label: DriverAuthStrings.email,
                  hint: DriverAuthStrings.emailHint,
                  icon: Icons.mail_outline_rounded,
                  controller: _emailCtrl,
                  enabled: !_loading,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  validator: (v) => v == null || v.trim().isEmpty
                      ? DriverAuthStrings.missingEmail
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                DriverAuthField(
                  label: DriverAuthStrings.password,
                  hint: DriverAuthStrings.passwordHint,
                  icon: Icons.lock_outline_rounded,
                  controller: _passwordCtrl,
                  password: true,
                  enabled: !_loading,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: (v) => v == null || v.isEmpty
                      ? DriverAuthStrings.missingPassword
                      : null,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  DriverAuthNotice(message: _errorMessage!, error: true),
                ],
                const SizedBox(height: AppSpacing.xl2),
                DriverAuthButton(
                  label: DriverAuthStrings.login,
                  loadingLabel: DriverAuthStrings.loggingIn,
                  loading: _loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  children: [
                    Text(
                      DriverAuthStrings.noAccount,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => context.go('/register'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        minimumSize: const Size(48, 48),
                        textStyle: AppTextStyles.labelMedium,
                      ),
                      child: const Text(DriverAuthStrings.register),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
