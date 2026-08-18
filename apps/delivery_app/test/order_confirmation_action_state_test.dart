import 'package:delivery_app/features/customer/screens/create_order/utils/order_confirmation_action_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('background payment polling does not make the action button busy', () {
    final beforePoll = isOrderConfirmationActionBusy(
      isSubmitting: false,
      isBackgroundPaymentCheck: false,
    );
    final duringPoll = isOrderConfirmationActionBusy(
      isSubmitting: false,
      isBackgroundPaymentCheck: true,
    );

    expect(beforePoll, isFalse);
    expect(duringPoll, isFalse);
  });

  test('explicit payment action keeps the action button busy', () {
    final busy = isOrderConfirmationActionBusy(
      isSubmitting: false,
      isBackgroundPaymentCheck: true,
      isUserPaymentAction: true,
    );

    expect(busy, isTrue);
  });
}
