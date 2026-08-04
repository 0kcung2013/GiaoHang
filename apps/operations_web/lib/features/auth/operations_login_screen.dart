import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'operations_account_aliases.dart';
import 'widgets/operations_brand_panel.dart';
import 'widgets/operations_login_content.dart';

class OperationsLoginScreen extends StatefulWidget {
  const OperationsLoginScreen({super.key});

  @override
  State<OperationsLoginScreen> createState() => _OperationsLoginScreenState();
}

class _OperationsLoginScreenState extends State<OperationsLoginScreen> {
  final _account = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _account.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_account.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Vui lòng nhập đầy đủ tài khoản và mật khẩu.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: resolveOperationsLogin(_account.text),
        password: _password.text,
      );
    } on AuthException {
      if (mounted) {
        setState(
          () => _error = 'Tài khoản hoặc mật khẩu chưa đúng. Vui lòng thử lại.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Không thể kết nối hệ thống. Vui lòng thử lại sau.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final showBrandPanel = constraints.maxWidth >= 900;
          return Row(
            children: [
              if (showBrandPanel)
                const Expanded(flex: 5, child: OperationsBrandPanel()),
              Expanded(
                flex: 6,
                child: OperationsLoginContent(
                  compact: !showBrandPanel,
                  accountController: _account,
                  passwordController: _password,
                  loading: _loading,
                  obscurePassword: _obscurePassword,
                  error: _error,
                  onTogglePassword: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  onSignIn: _signIn,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
