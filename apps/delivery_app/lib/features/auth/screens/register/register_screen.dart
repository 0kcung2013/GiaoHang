import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../core/services/auth_service.dart';
import '../driver_auth/wizard/driver_register_prefill.dart';
import '../widgets/auth_form_components.dart';
import '../widgets/auth_role_selector.dart';
import '../widgets/auth_strings.dart';
import 'widgets/register_field.dart';
import 'widgets/register_role_picker.dart';
import 'widgets/register_shell.dart';
import 'widgets/register_submit_button.dart';

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
    if (_loading) return;
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
    return RegisterShell(
      onBack: () => context.go('/login'),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              RegisterRolePicker(
                role: _role,
                onChanged: (role) => setState(() => _role = role),
              ),
              const SizedBox(height: AppSpacing.xl2),
              RegisterField(
                controller: _fullNameController,
                label: AuthStrings.fullName,
                icon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: _validateName,
              ),
              const SizedBox(height: AppSpacing.md),
              RegisterField(
                controller: _emailController,
                label: AuthStrings.email,
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newUsername],
                validator: _validateEmail,
              ),
              const SizedBox(height: AppSpacing.md),
              RegisterField(
                controller: _phoneController,
                label: AuthStrings.phone,
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: _validatePhone,
              ),
              const SizedBox(height: AppSpacing.md),
              RegisterField(
                controller: _passwordController,
                label: AuthStrings.password,
                hint: AuthStrings.passwordHint,
                icon: Icons.lock_outline_rounded,
                textInputAction: TextInputAction.done,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.newPassword],
                validator: _validatePassword,
                onSubmitted: (_) => _submit(),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  tooltip: _obscurePassword
                      ? AuthStrings.showPassword
                      : AuthStrings.hidePassword,
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              AnimatedSize(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : AppDuration.normal,
                alignment: Alignment.topCenter,
                child: _role == 'driver'
                    ? const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.md),
                        child: AuthInfoNote(message: AuthStrings.driverNote),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              if (_errorMessage case final message?) ...[
                const SizedBox(height: AppSpacing.md),
                AuthErrorBanner(message: message),
              ],
              const SizedBox(height: AppSpacing.xl),
              RegisterSubmitButton(
                driver: _role == 'driver',
                busy: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
