import 'package:delivery_app/features/driver/screens/navigation/models/driver_position_source.dart';
import 'package:delivery_app/features/returns/utils/return_confirmation_position_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web server-profile arrival rechecks the same server GPS source', () {
    final strategy = ReturnConfirmationPositionPolicy.resolve(
      isWeb: true,
      displayedSource: DriverPositionSource.serverProfile,
    );

    expect(strategy, ReturnConfirmationPositionStrategy.serverProfile);
  });

  test('simulation keeps the displayed arrival point', () {
    final strategy = ReturnConfirmationPositionPolicy.resolve(
      isWeb: true,
      displayedSource: DriverPositionSource.simulation,
    );

    expect(strategy, ReturnConfirmationPositionStrategy.displayedPosition);
  });

  test('device navigation refreshes live device GPS', () {
    final strategy = ReturnConfirmationPositionPolicy.resolve(
      isWeb: false,
      displayedSource: DriverPositionSource.deviceGps,
    );

    expect(strategy, ReturnConfirmationPositionStrategy.liveGps);
  });
}
