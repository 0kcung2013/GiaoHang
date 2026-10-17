import 'package:giaohang_mobile/core/location/driver_active_delivery_tracking_policy.dart';
import 'package:giaohang_mobile/core/location/driver_location_producer_policy.dart';
import 'package:giaohang_mobile/core/providers/driver_nav_session_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _returnSession = DriverNavSession(
  orderId: 'order-1',
  status: 'returning',
  lat: 10.785,
  lng: 106.69,
  arrivedAtTarget: true,
  routeCompleted: true,
  locationMode: DriverLocationMode.demoHcm,
);

bool _canRestore(
  DriverNavSession session, {
  String status = 'returning',
  String orderId = 'order-1',
  DriverLocationMode mode = DriverLocationMode.demoHcm,
}) => session.canRestoreFor(
  activeOrderId: orderId,
  activeStatus: status,
  activeLocationMode: mode,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a return session keeps background device GPS from resetting demo', () {
    expect(_canRestore(_returnSession), isTrue);
    expect(
      DriverActiveDeliveryTrackingPolicy.shouldUseLiveGps(
        isWeb: true,
        locationMode: DriverLocationMode.demoHcm,
        isNavigationMapOpen: false,
        hasRestoredNavigationSession: _canRestore(_returnSession),
      ),
      isFalse,
    );
  });

  test('return progress never restores into the delivery leg', () {
    expect(_canRestore(_returnSession, status: 'delivering'), isFalse);
    expect(_canRestore(_returnSession.copyWith(status: 'delivering')), isFalse);
  });

  test('delivery progress still restores across pickup and delivery', () {
    expect(
      _canRestore(
        _returnSession.copyWith(status: 'picking_up'),
        status: 'delivering',
      ),
      isTrue,
    );
  });

  test('completed returns and other orders do not restore', () {
    expect(_canRestore(_returnSession, status: 'returned'), isFalse);
    expect(_canRestore(_returnSession, orderId: 'order-2'), isFalse);
  });

  test('changing GPS mode discards the simulated return position', () {
    expect(
      _canRestore(_returnSession, mode: DriverLocationMode.deviceGps),
      isFalse,
    );
  });

  test('invalid return coordinates do not restore', () {
    expect(_canRestore(_returnSession.copyWith(lat: double.nan)), isFalse);
    expect(_canRestore(_returnSession.copyWith(lng: 181)), isFalse);
  });

  test('the return handoff survives persistent session hydration', () async {
    SharedPreferences.setMockInitialValues({});
    final firstRun = DriverNavSessionsNotifier();
    await firstRun.hydrate();
    await firstRun.upsert(_returnSession);
    firstRun.dispose();
    final nextRun = DriverNavSessionsNotifier();
    addTearDown(nextRun.dispose);
    await nextRun.hydrate();
    final restored = nextRun.state['order-1']!;
    expect(_canRestore(restored), isTrue);
    expect(restored.lat, _returnSession.lat);
    expect(restored.lng, _returnSession.lng);
    expect(restored.routeCompleted, isTrue);
  });
}
