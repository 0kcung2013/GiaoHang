import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../core/services/auth_service.dart';
import '../driver_auth/wizard/driver_register_prefill.dart';
import '../widgets/auth_form_components.dart';
import '../widgets/auth_role_selector.dart';
import '../widgets/auth_shell.dart';
import '../widgets/auth_strings.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  String _role = 'customer';
  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_role == 'driver') {
      context.go(
        '/driver-auth',
        extra: DriverRegisterPrefill(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          phone: _phoneController.text.trim(),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await _authService.signUpCustomer(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      if (mounted) context.go('/customer-home');
    } on AuthException catch (error) {
      if (!mounted) return;
      final normalized = error.message.toLowerCase();
      final message = normalized.contains('already')
          ? AuthStrings.emailExists
          : normalized.contains('password')
          ? AuthStrings.invalidPassword
          : error.message;
      setState(() => _errorMessage = message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = AuthStrings.registerFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validateName(String? value) {
    return value == null || value.trim().isEmpty
        ? AuthStrings.missingName
        : null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return AuthStrings.missingEmail;
    if (!email.contains('@') || !email.contains('.')) {
      return AuthStrings.invalidEmail;
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return AuthStrings.missingPhone;
    return phone.length < 10 ? AuthStrings.invalidPhone : null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return AuthStrings.missingPassword;
    return value.length < 6 ? AuthStrings.invalidPassword : null;
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: AuthStrings.registerTitle,
      subtitle: AuthStrings.registerSubtitle,
      onBack: () => context.go('/login'),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              AuthRoleSelector(
                role: _role,
                onChanged: (role) => setState(() => _role = role),
              ),
              const SizedBox(height: AppSpacing.lg),
              AuthTextField(
                controller: _fullNameController,
                label: AuthStrings.fullName,
                icon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: _validateName,
              ),
              const SizedBox(height: AppSpacing.md),
              AuthTextField(
                controller: _emailController,
                label: AuthStrings.email,
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newUsername],
                validator: _validateEmail,
              ),
              const SizedBox(height: AppSpacing.md),
              AuthTextField(
                controller: _phoneController,
                label: AuthStrings.phone,
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: _validatePhone,
              ),
              const SizedBox(height: AppSpacing.md),
              AuthTextField(
                controller: _passwordController,
                label: '${AuthStrings.password} · ${AuthStrings.passwordHint}',
                icon: Icons.lock_outline_rounded,
                textInputAction: TextInputAction.done,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.newPassword],
                validator: _validatePassword,
                onSubmitted: (_) => _submit(),
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
              if (_role == 'driver') ...[
                const SizedBox(height: AppSpacing.md),
                const AuthInfoNote(message: AuthStrings.driverNote),
              ],
              if (_errorMessage case final message?) ...[
                const SizedBox(height: AppSpacing.md),
                AuthErrorBanner(message: message),
              ],
              const SizedBox(height: AppSpacing.xl),
              AuthPrimaryButton(
                label: _role == 'driver'
                    ? AuthStrings.driverNext
                    : AuthStrings.register,
                busyLabel: AuthStrings.registering,
                isBusy: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.sm),
              AuthSwitchPrompt(
                prompt: AuthStrings.haveAccount,
                actionLabel: AuthStrings.backToLogin,
                onPressed: () => context.go('/login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
