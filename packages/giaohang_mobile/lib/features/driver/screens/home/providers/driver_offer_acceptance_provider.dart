import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/location/driver_demo_offer_acceptance.dart';
import '../../../../../core/location/driver_location_producer_policy.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../../../../../core/providers/location_providers.dart';

typedef DriverOfferAcceptance =
    Future<void> Function(
      OrderModel order,
      String driverUserId, {
      String? orderCodeHint,
    });

/// Hai lối nhận lời mời cùng xác nhận GPS demo trước khi backend cấp ETA.
final driverOfferAcceptanceProvider = Provider<DriverOfferAcceptance>((ref) {
  final orders = ref.watch(customerOrderServiceProvider);
  final drivers = ref.watch(driverServiceProvider);
  final ingest = ref.watch(locationIngestServiceProvider);
  return (order, driverUserId, {orderCodeHint}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user?.id != driverUserId) {
      throw Exception('Chỉ tài xế đang đăng nhập mới có thể nhận đơn.');
    }
    await acceptAfterDemoLocationSync(
      mode: ref.read(driverLocationModeProvider),
      email: user?.email,
      trafficDemoKey: order.trafficDemoKey,
      publish: (position) => ingest.ingest(
        driverUserId: driverUserId,
        lat: position.latitude,
        lng: position.longitude,
        force: true,
        // Force latest PG bằng đường đang dùng ở navigation: Redis có thể
        // vừa được touch nhưng ETA đọc drivers, không đọc marker ở client.
        prioritySync: true,
        coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
      ),
      readLatest: () async {
        final driver = await drivers.getDriverByUserId(driverUserId);
        if (driver?.currentLat == null || driver?.currentLng == null) {
          return null;
        }
        return LatLng(driver!.currentLat!, driver.currentLng!);
      },
      accept: () => orders.acceptOrder(
        order.id,
        driverUserId,
        customerIdHint: order.customerId,
        orderCodeHint: orderCodeHint,
      ),
    );
  };
});
