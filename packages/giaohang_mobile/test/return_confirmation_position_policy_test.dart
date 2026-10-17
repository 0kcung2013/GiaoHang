import 'package:giaohang_mobile/features/driver/screens/navigation/models/driver_position_source.dart';
import 'package:giaohang_mobile/features/returns/utils/return_confirmation_position_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restored simulation keeps its displayed handoff position', () {
    expect(
      ReturnConfirmationPositionPolicy.resolve(
        usesRouteSimulation: true,
        displayedSource: DriverPositionSource.restoredSession,
      ),
      ReturnConfirmationPositionStrategy.displayedPosition,
    );
    expect(
      ReturnConfirmationPositionPolicy.resolve(
        usesRouteSimulation: false,
        displayedSource: DriverPositionSource.restoredSession,
      ),
      ReturnConfirmationPositionStrategy.liveGps,
    );
  });
  test('web server-profile arrival rechecks the same server GPS source', () {
    final strategy = ReturnConfirmationPositionPolicy.resolve(
      usesRouteSimulation: true,
      displayedSource: DriverPositionSource.serverProfile,
    );

    expect(strategy, ReturnConfirmationPositionStrategy.serverProfile);
  });

  test('simulation keeps the displayed arrival point', () {
    final strategy = ReturnConfirmationPositionPolicy.resolve(
      usesRouteSimulation: true,
      displayedSource: DriverPositionSource.simulation,
    );

    expect(strategy, ReturnConfirmationPositionStrategy.displayedPosition);
  });

  test('device navigation refreshes live device GPS', () {
    final strategy = ReturnConfirmationPositionPolicy.resolve(
      usesRouteSimulation: false,
      displayedSource: DriverPositionSource.deviceGps,
    );

    expect(strategy, ReturnConfirmationPositionStrategy.liveGps);
  });
}
