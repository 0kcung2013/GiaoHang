import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../core/services/auth_service.dart';
import '../widgets/auth_form_components.dart';
import '../widgets/auth_shell.dart';
import '../widgets/auth_strings.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    await _runAuthAction(() async {
      await _authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final role = await _authService.ensureUserRecord();
      if (mounted) _navigateByRole(role);
    });
  }

  Future<void> _signInWithGoogle() async {
    await _runAuthAction(() async {
      await _authService.signInWithGoogle();
      final role = await _authService.ensureUserRecord();
      if (mounted) _navigateByRole(role);
    });
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await action();
    } on AuthException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = AuthStrings.loginFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateByRole(String role) {
    final route = switch (role) {
      'admin' || 'support' => '/operations-required',
      'driver' => '/driver-home',
      'customer' => '/customer-home',
      _ => '/unsupported-role',
    };
    context.go(route);
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return AuthStrings.missingEmail;
    if (!email.contains('@') || !email.contains('.')) {
      return AuthStrings.invalidEmail;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    return value == null || value.isEmpty ? AuthStrings.missingPassword : null;
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: AuthStrings.loginTitle,
      subtitle: AuthStrings.loginSubtitle,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              AuthTextField(
                controller: _emailController,
                label: AuthStrings.email,
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: _validateEmail,
              ),
              const SizedBox(height: AppSpacing.md),
              AuthTextField(
                controller: _passwordController,
                label: AuthStrings.password,
                icon: Icons.lock_outline_rounded,
                textInputAction: TextInputAction.done,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
                validator: _validatePassword,
                onSubmitted: (_) => _signInWithEmail(),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (_errorMessage case final message?) ...[
                const SizedBox(height: AppSpacing.md),
                AuthErrorBanner(message: message),
              ],
              const SizedBox(height: AppSpacing.xl),
              AuthPrimaryButton(
                label: AuthStrings.login,
                busyLabel: AuthStrings.loggingIn,
                isBusy: _loading,
                onPressed: _signInWithEmail,
              ),
              const SizedBox(height: AppSpacing.lg),
              const AuthDivider(),
              const SizedBox(height: AppSpacing.lg),
              AuthGoogleButton(isBusy: _loading, onPressed: _signInWithGoogle),
              const SizedBox(height: AppSpacing.sm),
              AuthSwitchPrompt(
                prompt: AuthStrings.noAccount,
                actionLabel: AuthStrings.registerNow,
                onPressed: () => context.push('/register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
