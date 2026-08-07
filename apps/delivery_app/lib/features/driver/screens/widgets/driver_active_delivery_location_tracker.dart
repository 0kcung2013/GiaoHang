import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/driver_location_producer_policy.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/providers/customer_providers.dart';
import '../../../../core/providers/driver_nav_session_provider.dart';
import '../../../../core/providers/location_providers.dart';
import '../home/utils/driver_home_formatters.dart';
import '../navigation/utils/driver_navigation_resume_policy.dart';

typedef _DemoSessionPresenceRequest = ({
  String driverProfileId,
  String driverUserId,
  double lat,
  double lng,
});

/// Giữ last-known location còn sống khi bản demo đóng Map.
final _demoSessionPresenceProvider = StreamProvider.autoDispose
    .family<void, _DemoSessionPresenceRequest>((ref, request) {
      final ingest = ref.watch(locationIngestServiceProvider);

      Future<void> publish() {
        return ingest.ingest(
          driverProfileId: request.driverProfileId,
          driverUserId: request.driverUserId,
          lat: request.lat,
          lng: request.lng,
          prioritySync: true,
          coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
        );
      }

      unawaited(publish());
      final timer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => unawaited(publish()),
      );
      ref.onDispose(timer.cancel);
      return const Stream<void>.empty();
    });

/// GPS bền vững ở cấp Driver Shell, không phụ thuộc route Map đang mở hay đóng.
class DriverActiveDeliveryLocationTracker extends ConsumerWidget {
  const DriverActiveDeliveryLocationTracker({
    super.key,
    required this.userId,
    required this.email,
  });

  final String userId;
  final String? email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(driverByUserIdProvider(userId)).valueOrNull;
    final orders = ref.watch(driverOrdersProvider(userId)).valueOrNull;
    final activeOrders =
        orders?.where(isActiveDriverOrder).toList() ?? const <OrderModel>[];
    final activeOrder = activeOrders.isEmpty ? null : activeOrders.first;
    if (driver == null || activeOrder == null) return const SizedBox.shrink();

    final session = ref.watch(driverNavSessionsProvider)[activeOrder.id];
    final isNavigationMapOpen =
        ref.watch(activeDriverNavigationOrderProvider) == activeOrder.id;
    final keepDemoSession =
        DriverNavigationResumePolicy.shouldKeepRestoredPosition(
          hasRestoredPosition:
              session != null &&
              session.canRestoreFor(
                activeOrderId: activeOrder.id,
                activeStatus: activeOrder.status,
              ),
          driverEmail: email,
        );

    if (isNavigationMapOpen) {
      return const SizedBox.shrink();
    }

    if (keepDemoSession) {
      ref.watch(
        _demoSessionPresenceProvider((
          driverProfileId: driver.id,
          driverUserId: driver.userId,
          lat: session!.lat,
          lng: session.lng,
        )),
      );
      return const SizedBox.shrink();
    }

    ref.watch(driverLocationStreamProvider(driver.id));
    return const SizedBox.shrink();
  }
}
