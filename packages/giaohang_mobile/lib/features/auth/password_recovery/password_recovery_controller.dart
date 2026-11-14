import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/password_recovery_service.dart';
import 'password_recovery_strings.dart';

enum PasswordRecoveryStep { email, code, password, success }

class PasswordRecoveryController extends ChangeNotifier {
  PasswordRecoveryController({
    required PasswordRecoveryGateway gateway,
    DateTime Function()? now,
  }) : _gateway = gateway,
       _now = now ?? DateTime.now;

  final PasswordRecoveryGateway _gateway;
  final DateTime Function() _now;
  PasswordRecoveryStep step = PasswordRecoveryStep.email;
  String email = '';
  String? error;
  bool busy = false;
  int resendSeconds = 0;
  Timer? _timer;
  DateTime? _resendAt;
  bool _disposed = false;

  Future<void> sendCode(String value) async {
    if (busy ||
        resendSeconds > 0 ||
        (step != PasswordRecoveryStep.email &&
            step != PasswordRecoveryStep.code)) {
      return;
    }
    final address = value.trim();
    await _run(() async {
      await _gateway.sendCode(address);
      if (_disposed) return;
      email = address;
      step = PasswordRecoveryStep.code;
      _startCooldown();
    }, fallback: PasswordRecoveryStrings.sendFailed);
  }

  Future<void> verifyCode(String code) async {
    if (busy || step != PasswordRecoveryStep.code) return;
    await _run(() async {
      await _gateway.verifyCode(email, code.trim());
      if (!_disposed) step = PasswordRecoveryStep.password;
    }, fallback: PasswordRecoveryStrings.verifyFailed);
  }

  Future<void> savePassword(String password) async {
    if (busy || step != PasswordRecoveryStep.password) return;
    await _run(() async {
      await _gateway.updatePassword(password);
      if (_disposed) return;
      step = PasswordRecoveryStep.success;
      _timer?.cancel();
    }, fallback: PasswordRecoveryStrings.saveFailed);
  }

  void changeEmail() {
    if (busy || step != PasswordRecoveryStep.code) return;
    step = PasswordRecoveryStep.email;
    error = null;
    notifyListeners();
  }

  void _startCooldown() {
    _resendAt = _now().add(const Duration(seconds: 60));
    resendSeconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      resendSeconds = (_resendAt!.difference(_now()).inMilliseconds / 1000)
          .ceil()
          .clamp(0, 60);
      if (resendSeconds == 0) _timer?.cancel();
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String fallback,
  }) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (exception) {
      if (!_disposed) error = _message(exception, fallback);
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  String _message(Object exception, String fallback) {
    if (exception is AuthException) {
      switch (exception.code) {
        case 'over_email_send_rate_limit':
        case 'over_request_rate_limit':
          _startCooldown();
          return PasswordRecoveryStrings.rateLimited;
        case 'otp_expired':
        case 'access_denied':
          return PasswordRecoveryStrings.codeExpired;
        case 'session_expired':
        case 'session_not_found':
        case 'refresh_token_not_found':
        case 'bad_jwt':
          step = PasswordRecoveryStep.code;
          return PasswordRecoveryStrings.sessionExpired;
        case 'same_password':
          return PasswordRecoveryStrings.samePassword;
        case 'weak_password':
          return PasswordRecoveryStrings.weakPassword;
        case 'user_banned':
          return PasswordRecoveryStrings.accountUnavailable;
      }
      if (exception.statusCode == '429') {
        _startCooldown();
        return PasswordRecoveryStrings.rateLimited;
      }
    }
    return fallback;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_gateway.dispose());
    super.dispose();
  }
}
