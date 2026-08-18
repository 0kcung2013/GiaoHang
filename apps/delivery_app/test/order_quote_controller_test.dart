import 'package:delivery_app/features/customer/screens/create_order/controllers/order_quote_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quote requires both pickup and delivery positions', () {
    final controller = OrderQuoteController(
      estimator:
          ({
            required pickupLat,
            required pickupLng,
            required deliveryLat,
            required deliveryLng,
            required serviceType,
          }) => throw StateError('estimator must not run'),
    );

    expect(
      () => controller.calculate(
        pickupLat: 0,
        pickupLng: 0,
        deliveryLat: 10.8,
        deliveryLng: 106.7,
      ),
      throwsA(isA<OrderQuoteException>()),
    );
  });

  test('valid positions are quoted before customer information', () async {
    var called = false;
    final controller = OrderQuoteController(
      estimator:
          ({
            required pickupLat,
            required pickupLng,
            required deliveryLat,
            required deliveryLng,
            required serviceType,
          }) {
            called = true;
            expect(serviceType, 'standard');
            return Future.error(StateError('quote sentinel'));
          },
    );

    await expectLater(
      controller.calculate(
        pickupLat: 10.775,
        pickupLng: 106.68,
        deliveryLat: 10.825,
        deliveryLng: 106.73,
      ),
      throwsStateError,
    );
    expect(called, isTrue);
  });
}
