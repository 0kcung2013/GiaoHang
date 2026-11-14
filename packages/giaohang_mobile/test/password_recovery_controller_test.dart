import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/features/auth/password_recovery/data/password_recovery_service.dart';
import 'package:giaohang_mobile/features/auth/password_recovery/password_recovery_controller.dart';
import 'package:giaohang_mobile/features/auth/password_recovery/password_recovery_strings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('resend waits 60 seconds even when changing the email', () {
    fakeAsync((time) {
      final gateway = _Gateway();
      final start = DateTime.utc(2026, 11, 7);
      final controller = PasswordRecoveryController(
        gateway: gateway,
        now: () => start.add(time.elapsed),
      );
      controller.sendCode('customer@example.test');
      time.flushMicrotasks();
      controller.changeEmail();
      controller.sendCode('other@example.test');
      time.flushMicrotasks();
      expect(gateway.sends, 1);
      time.elapse(const Duration(seconds: 60));
      expect(controller.resendSeconds, 0);
      controller.sendCode('other@example.test');
      time.flushMicrotasks();
      expect(gateway.sends, 2);
      expect(controller.email, 'other@example.test');
      expect(controller.step, PasswordRecoveryStep.code);
      controller.dispose();
    });
  });

  test('server rate limits display a cooldown and do not advance the form', () {
    fakeAsync((time) {
      final gateway = _Gateway()
        ..sendError = const AuthException(
          'Too many requests',
          statusCode: '429',
        );
      final controller = PasswordRecoveryController(gateway: gateway);
      controller.sendCode('customer@example.test');
      time.flushMicrotasks();
      expect(controller.step, PasswordRecoveryStep.email);
      expect(controller.error, PasswordRecoveryStrings.rateLimited);
      expect(controller.resendSeconds, 60);
      expect(controller.busy, isFalse);
      controller.dispose();
    });
  });

  test('network failure on resend keeps the email and shows a send error', () {
    final gateway = _Gateway();
    var now = DateTime.utc(2026, 11, 7);
    fakeAsync((time) {
      final active = PasswordRecoveryController(
        gateway: gateway,
        now: () => now,
      );
      active.sendCode('customer@example.test');
      time.flushMicrotasks();
      now = now.add(const Duration(seconds: 60));
      time.elapse(const Duration(seconds: 1));
      gateway.sendError = Exception('offline');
      active.sendCode(active.email);
      time.flushMicrotasks();
      expect(active.email, 'customer@example.test');
      expect(active.step, PasswordRecoveryStep.code);
      expect(active.error, PasswordRecoveryStrings.sendFailed);
      active.dispose();
    });
  });
}

class _Gateway implements PasswordRecoveryGateway {
  int sends = 0;
  Object? sendError;
  @override
  Future<void> sendCode(String email) async {
    sends++;
    if (sendError != null) throw sendError!;
  }

  @override
  Future<void> verifyCode(String email, String code) async {}
  @override
  Future<void> updatePassword(String password) async {}
  @override
  Future<void> dispose() async {}
}
