import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/core/models/customer_wallet_pin.dart';
import 'package:giaohang_mobile/core/services/customer_wallet_pin_service.dart';

void main() {
  test('status uses server time even when the device clock differs', () async {
    final service = CustomerWalletPinService(
      rpcInvoker: (name, params) async {
        expect(name, 'get_customer_wallet_pin_status');
        return {
          'ok': true,
          'is_configured': true,
          'attempts_remaining': 0,
          'server_now': '2026-01-01T00:00:00Z',
          'locked_until': '2026-01-01T00:12:00Z',
        };
      },
    );
    final status = await service.getStatus();
    expect(status.isLocked, isTrue);
    expect(status.lockRemaining, const Duration(minutes: 12));
  });

  test(
    'setup preserves leading zeroes and never sends the profile or ledger',
    () async {
      final service = CustomerWalletPinService(
        rpcInvoker: (name, params) async {
          expect(name, 'set_customer_wallet_pin');
          expect(params, {'p_new_pin': '001234', 'p_current_pin': null});
          return {'ok': true};
        },
      );
      await service.setPin('001234');
    },
  );

  test('wrong current PIN exposes the server attempt result', () async {
    final service = CustomerWalletPinService(
      rpcInvoker: (_, _) async => {
        'ok': false,
        'code': 'PIN_INVALID',
        'attempts_remaining': 2,
      },
    );
    await expectLater(
      service.setPin('001234', currentPin: '999999'),
      throwsA(
        isA<CustomerWalletPinException>().having(
          (e) => e.message,
          'message',
          contains('2 lần thử'),
        ),
      ),
    );
  });
}
