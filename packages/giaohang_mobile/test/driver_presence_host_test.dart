import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_mobile/core/location/driver_location_producer_policy.dart';
import 'package:giaohang_mobile/core/location/driver_presence_session.dart';
import 'package:giaohang_mobile/core/location/location_ingest_service.dart';
import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/core/providers/customer_providers.dart';
import 'package:giaohang_mobile/core/providers/driver_online_presence_provider.dart';
import 'package:giaohang_mobile/features/driver/screens/widgets/driver_online_presence_host.dart';

import 'driver_presence_session_test.dart' show Gps, fix;
import 'helpers/utraffic_capture_fonts.dart';

class _Transport implements LocationIngestService {
  int calls = 0;
  bool available = true;
  @override
  LatLng resolveCoordinates({
    required LocationIngestCoordinateSpace coordinateSpace,
    required double lat,
    required double lng,
  }) => LatLng(lat, lng);
  @override
  Future<bool> ingestOnlinePresence({
    String? driverProfileId,
    String? driverUserId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
    double? accuracy,
    DateTime? capturedAt,
    LocationIngestCoordinateSpace coordinateSpace =
        LocationIngestCoordinateSpace.rawGps,
  }) async {
    calls++;
    return available;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(prepareUtrafficCaptureFonts);

  testWidgets(
    'session survives tab content errors; resume syncs; active task stops only idle GPS',
    (tester) async {
      final gps = Gps(() async => fix(DateTime.now()));
      final transport = _Transport();
      final orders = StreamController<List<OrderModel>>();
      final container = ProviderContainer(
        overrides: [
          driverOnlineLocationServiceProvider.overrideWithValue(gps),
          locationIngestServiceProvider.overrideWithValue(transport),
          driverByUserIdProvider('driver').overrideWith(
            (_) async => DriverModel(
              id: 'profile',
              userId: 'driver',
              isAvailable: true,
              updatedAt: DateTime.now(),
              totalDeliveries: 0,
            ),
          ),
          driverOrdersProvider('driver').overrideWith((_) => orders.stream),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: DriverOnlinePresenceHost(
                userId: 'driver',
                child: Text('Lỗi tải danh sách đơn'),
              ),
            ),
          ),
        ),
      );
      orders.addError(StateError('orders temporarily unavailable'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(transport.calls, greaterThanOrEqualTo(1));
      expect(gps.tracking, isTrue);
      orders.add([]);
      await tester.pump();
      expect(find.text('Chưa sẵn sàng nhận đơn'), findsNothing);
      final beforeResume = transport.calls;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(transport.calls, greaterThan(beforeResume));
      orders.add([
        OrderModel.fromJson({
          'id': 'task',
          'driver_id': 'driver',
          'customer_id': 'customer',
          'status': 'assigned',
          'pickup_address': 'Lấy',
          'delivery_address': 'Giao',
          'pickup_lat': 10.8,
          'pickup_lng': 106.7,
          'delivery_lat': 10.81,
          'delivery_lng': 106.71,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
      ]);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(gps.tracking, isFalse);
      orders.add([]);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(gps.tracking, isTrue);
      expect(gps.starts, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      unawaited(orders.close());
    },
  );

  for (final size in [
    const Size(320, 568),
    Devices.android.samsungGalaxyS20.screenSize,
    const Size(1024, 768),
  ]) {
    testWidgets('GPS statuses never insert banners or shift content at $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      const contentKey = ValueKey('driver-tab-content');

      for (final status in [
        DriverPresenceStatus.gpsTimedOut,
        ...DriverPresenceStatus.values.where(
          (value) => value != DriverPresenceStatus.gpsTimedOut,
        ),
      ]) {
        final gps = Gps(() async => null);
        final session = DriverPresenceSession(
          location: gps,
          publish: (_) async => false,
          onPosition: (_) {},
        )..status = status;
        final container = ProviderContainer(
          overrides: [
            driverByUserIdProvider('driver').overrideWith(
              (_) async => DriverModel(
                id: 'profile',
                userId: 'driver',
                isAvailable: true,
                updatedAt: DateTime.now(),
                totalDeliveries: 0,
              ),
            ),
            driverOrdersProvider(
              'driver',
            ).overrideWith((_) => Stream.value([])),
            driverPresenceSessionProvider(
              'profile',
            ).overrideWith((_) => session),
          ],
        );
        final boundary = GlobalKey();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            key: ValueKey(status),
            container: container,
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(1.6),
                ),
                child: RepaintBoundary(
                  key: boundary,
                  child: Scaffold(
                    backgroundColor: AppColors.bgLight,
                    body: DriverOnlinePresenceHost(
                      userId: 'driver',
                      child: SizedBox.expand(
                        key: contentKey,
                        child: Center(
                          child: Text(
                            'Tổng quan',
                            style: AppTextStyles.headingMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // The session must stay mounted even though it has no status UI.
        expect(
          container.exists(driverPresenceSessionProvider('profile')),
          isTrue,
        );
        expect(
          find.text('Chưa sẵn sàng nhận đơn'),
          findsNothing,
          reason: status.name,
        );
        expect(
          find.text('Đang cập nhật vị trí'),
          findsNothing,
          reason: status.name,
        );
        expect(find.text('Thử lại GPS'), findsNothing, reason: status.name);
        expect(
          tester.getTopLeft(find.byKey(contentKey)),
          Offset.zero,
          reason: status.name,
        );
        expect(
          tester.getSize(find.byKey(contentKey)),
          size,
          reason: status.name,
        );
        expect(tester.takeException(), isNull, reason: status.name);

        if (size == Devices.android.samsungGalaxyS20.screenSize &&
            status == DriverPresenceStatus.gpsTimedOut) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final output = File(
              '../../artifacts/driver_presence_without_banner.png',
            );
            await output.parent.create(recursive: true);
            await output.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        session.dispose();
        await tester.pump();
      }
    });
  }
}
