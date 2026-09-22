import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/auth_service.dart';
import '../widgets/auth_strings.dart';
import 'widgets/login_experiment_view.dart';

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
    return LoginExperimentView(
      formKey: _formKey,
      emailController: _emailController,
      passwordController: _passwordController,
      isBusy: _loading,
      obscurePassword: _obscurePassword,
      errorMessage: _errorMessage,
      emailValidator: _validateEmail,
      passwordValidator: _validatePassword,
      onEmailSignIn: _signInWithEmail,
      onGoogleSignIn: _signInWithGoogle,
      onTogglePassword: () =>
          setState(() => _obscurePassword = !_obscurePassword),
      onRegister: () => context.push('/register'),
      onPasswordSubmitted: (_) => _signInWithEmail(),
    );
  }
}
