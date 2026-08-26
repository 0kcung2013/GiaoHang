import 'package:delivery_app/core/location/driver_location_producer_policy.dart';
import 'package:delivery_app/core/services/driver_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('publishes fresh GPS before the atomic online command', () async {
    final events = <String>[];
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    final service = DriverService(
      client: client,
      locationPublisher:
          ({
            required driverProfileId,
            required lat,
            required lng,
            heading,
            speed,
          }) async {
            events.add('gps');
            expect(driverProfileId, 'driver-profile-1');
            expect(lat, 10.75);
            expect(lng, 106.67);
          },
      rpcInvoker: (name, params) async {
        events.add('rpc');
        expect(name, 'set_driver_online_with_location');
        expect(params, {'p_lat': 10.75, 'p_lng': 106.67});
        return 'order-1';
      },
    );

    final offeredOrderId = await service.setOnlineWithLocation(
      driverProfileId: 'driver-profile-1',
      lat: 10.75,
      lng: 106.67,
      coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
    );

    expect(events, ['gps', 'rpc']);
    expect(offeredOrderId, 'order-1');
  });
}
