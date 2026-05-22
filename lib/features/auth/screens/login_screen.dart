import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  bool _loading = false;
  String? _errorMessage;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await _authService.signInWithGoogle();
      final user = _authService.getCurrentUser();
      if (user != null && mounted) {
        final role = await _authService.fetchUserRole();
        if (!mounted) return;
        final route = switch (role) {
          'admin' => '/admin-home',
          'driver' => '/driver-home',
          _ => '/customer-home',
        };
        context.go(route);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Đăng nhập thất bại. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E0E2A), Color(0xFF1A1A3E), Color(0xFF2D1B4E)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'DATN',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hệ thống Giao hàng Thông minh',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 56),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _signInWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF37352F),
                        disabledBackgroundColor:
                            Colors.white.withValues(alpha: 0.7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      icon: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF6B4FF8),
                              ),
                            )
                          : const Text(
                              'G',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4285F4),
                                fontFamily: 'sans-serif',
                              ),
                            ),
                      label: const Text(
                        'Đăng nhập với Google',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F0),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFD0D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFFE53935), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFE53935),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Tiếp tục với tài khoản Google của bạn',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.40),
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
