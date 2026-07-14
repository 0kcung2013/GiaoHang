import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _licensePlateCtrl = TextEditingController();

  String _role = 'customer';
  String _vehicleType = 'Xe máy';
  bool _loading = false;
  String? _errorMessage;

  static const _vehicleTypes = ['Xe máy', 'Ô tô con', 'Xe tải'];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _licensePlateCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      if (_role == 'driver') {
        await _authService.signUpDriver(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          fullName: _fullNameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          vehicleType: _vehicleType,
          licensePlate: _licensePlateCtrl.text.trim(),
        );
      } else {
        await _authService.signUpCustomer(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          fullName: _fullNameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
        );
      }

      if (!mounted) return;

      final route = _role == 'driver' ? '/driver-home' : '/customer-home';
      context.go(route);
    } on AuthException catch (e) {
      String msg;
      if (e.message.toLowerCase().contains('already')) {
        msg = 'Email này đã được đăng ký. Vui lòng đăng nhập.';
      } else if (e.message.toLowerCase().contains('password')) {
        msg = 'Mật khẩu phải có ít nhất 6 ký tự.';
      } else {
        msg = e.message;
      }
      setState(() => _errorMessage = msg);
    } catch (e) {
      setState(() => _errorMessage = 'Đăng ký thất bại. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.35),
        fontSize: 14,
      ),
      prefixIcon: Icon(
        icon,
        color: Colors.white.withValues(alpha: 0.4),
        size: 20,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.07),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF8A8A)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF8A8A)),
      ),
      errorStyle: const TextStyle(color: Color(0xFFFFB4B4), fontSize: 12),
    );
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
        child: Stack(
          children: [
            const Positioned(
              top: -80,
              left: -40,
              child: _BackgroundOrb(
                size: 220,
                color: Color(0xFF8B5CF6),
                opacity: 0.18,
              ),
            ),
            const Positioned(
              bottom: -70,
              right: 30,
              child: _BackgroundOrb(
                size: 200,
                color: Color(0xFFC77DFF),
                opacity: 0.12,
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 380),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  28,
                                  28,
                                  28,
                                  28,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  color: Colors.white.withValues(alpha: 0.10),
                                  border: Border.all(
                                    color: Colors.white.withValues(
                                      alpha: 0.18,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF120A2D,
                                      ).withValues(alpha: 0.28),
                                      blurRadius: 40,
                                      offset: const Offset(0, 18),
                                    ),
                                  ],
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Đăng ký',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Tạo tài khoản để sử dụng hệ thống',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white.withValues(
                                            alpha: 0.65,
                                          ),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 20),

                                      // Role selector
                                      Container(
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () => setState(
                                                  () => _role = 'customer',
                                                ),
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 200,
                                                  ),
                                                  margin:
                                                      const EdgeInsets.all(3),
                                                  decoration: BoxDecoration(
                                                    color: _role == 'customer'
                                                        ? const Color(
                                                            0xFF8B5CF6,
                                                          ).withValues(
                                                            alpha: 0.3,
                                                          )
                                                        : Colors.transparent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: _role == 'customer'
                                                        ? Border.all(
                                                            color: const Color(
                                                              0xFF8B5CF6,
                                                            ).withValues(
                                                              alpha: 0.5,
                                                            ),
                                                          )
                                                        : null,
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    'Khách hàng',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: _role ==
                                                              'customer'
                                                          ? Colors.white
                                                          : Colors.white
                                                                .withValues(
                                                                  alpha: 0.55,
                                                                ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () => setState(
                                                  () => _role = 'driver',
                                                ),
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 200,
                                                  ),
                                                  margin:
                                                      const EdgeInsets.all(3),
                                                  decoration: BoxDecoration(
                                                    color: _role == 'driver'
                                                        ? const Color(
                                                            0xFFFF6B35,
                                                          ).withValues(
                                                            alpha: 0.3,
                                                          )
                                                        : Colors.transparent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: _role == 'driver'
                                                        ? Border.all(
                                                            color: const Color(
                                                              0xFFFF6B35,
                                                            ).withValues(
                                                              alpha: 0.5,
                                                            ),
                                                          )
                                                        : null,
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    'Tài xế',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: _role == 'driver'
                                                          ? Colors.white
                                                          : Colors.white
                                                                .withValues(
                                                                  alpha: 0.55,
                                                                ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      TextFormField(
                                        controller: _fullNameCtrl,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        textInputAction: TextInputAction.next,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                        decoration: _inputDecoration(
                                          'Họ và tên',
                                          Icons.person_outlined,
                                        ),
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Vui lòng nhập họ tên';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _emailCtrl,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                        decoration: _inputDecoration(
                                          'Email',
                                          Icons.email_outlined,
                                        ),
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Vui lòng nhập email';
                                          }
                                          if (!v.contains('@') ||
                                              !v.contains('.')) {
                                            return 'Email không hợp lệ';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _phoneCtrl,
                                        keyboardType: TextInputType.phone,
                                        textInputAction: TextInputAction.next,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                        decoration: _inputDecoration(
                                          'Số điện thoại',
                                          Icons.phone_outlined,
                                        ),
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Vui lòng nhập số điện thoại';
                                          }
                                          if (v.trim().length < 10) {
                                            return 'Số điện thoại không hợp lệ';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _passwordCtrl,
                                        obscureText: true,
                                        textInputAction: TextInputAction.done,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                        decoration: _inputDecoration(
                                          'Mật khẩu (ít nhất 6 ký tự)',
                                          Icons.lock_outlined,
                                        ),
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Vui lòng nhập mật khẩu';
                                          }
                                          if (v.length < 6) {
                                            return 'Mật khẩu phải có ít nhất 6 ký tự';
                                          }
                                          return null;
                                        },
                                      ),

                                      if (_role == 'driver') ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.07,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: DropdownButtonFormField<
                                            String
                                          >(
                                            initialValue: _vehicleType,
                                            dropdownColor: const Color(
                                              0xFF1E1645,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
                                              prefixIcon: Icon(
                                                Icons
                                                    .directions_car_outlined,
                                                color: Colors.white38,
                                                size: 20,
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons
                                                  .keyboard_arrow_down_rounded,
                                              color: Colors.white70,
                                            ),
                                            isExpanded: true,
                                            items: _vehicleTypes
                                                .map(
                                                  (t) => DropdownMenuItem(
                                                    value: t,
                                                    child: Text(t),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (v) {
                                              if (v != null) {
                                                setState(
                                                  () => _vehicleType = v,
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: _licensePlateCtrl,
                                          textCapitalization:
                                              TextCapitalization.characters,
                                          textInputAction:
                                              TextInputAction.done,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                          decoration: _inputDecoration(
                                            'Biển số xe',
                                            Icons.pin_outlined,
                                          ),
                                          validator: (v) {
                                            if (v == null ||
                                                v.trim().isEmpty) {
                                              return 'Vui lòng nhập biển số xe';
                                            }
                                            return null;
                                          },
                                        ),
                                      ],

                                      if (_errorMessage != null) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            color: const Color(0x66A61E4D),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.14,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.error_outline,
                                                color: Color(0xFFFFB4C7),
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _errorMessage!,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 20),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 50,
                                        child: ElevatedButton(
                                          onPressed:
                                              _loading ? null : _submit,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _role == 'driver'
                                                ? const Color(0xFFFF6B35)
                                                : const Color(0xFF8B5CF6),
                                            foregroundColor: Colors.white,
                                            disabledBackgroundColor:
                                                (_role == 'driver'
                                                        ? const Color(
                                                            0xFFFF6B35,
                                                          )
                                                        : const Color(
                                                            0xFF8B5CF6,
                                                          ))
                                                    .withValues(alpha: 0.5),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            elevation: 0,
                                          ),
                                          child: _loading
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                )
                                              : const Text(
                                                  'Đăng ký',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Đã có tài khoản? ',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.white.withValues(
                                                alpha: 0.6,
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () =>
                                                context.pop(),
                                            child: Text(
                                              'Đăng nhập',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: _role == 'driver'
                                                    ? const Color(
                                                        0xFFFF6B35,
                                                      )
                                                    : const Color(
                                                        0xFF8B5CF6,
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _BackgroundOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }
}
