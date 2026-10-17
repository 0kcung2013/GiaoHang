import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:giaohang_mobile/core/location/driver_location_producer_policy.dart';
import 'package:giaohang_mobile/core/location/location_ingest_service.dart';
import 'package:giaohang_mobile/core/models/delivery_proof_model.dart';
import 'package:giaohang_mobile/core/models/driver_wallet.dart';
import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/core/providers/customer_providers.dart';
import 'package:giaohang_mobile/core/providers/driver_nav_session_provider.dart';
import 'package:giaohang_mobile/core/providers/driver_wallet_providers.dart';
import 'package:giaohang_mobile/core/providers/location_providers.dart';
import 'package:giaohang_mobile/core/services/customer_order_service.dart';
import 'package:giaohang_mobile/core/services/delivery_proof_service.dart';
import 'package:giaohang_mobile/core/services/delivery_proof_watermark_service.dart';
import 'package:giaohang_mobile/core/services/realtime_service.dart';
import 'package:giaohang_mobile/features/driver/cancellation/data/driver_cancellation_repository.dart';
import 'package:giaohang_mobile/features/driver/cancellation/driver_cancellation_providers.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/driver_navigation_screen.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/widgets/driver_delivery_confirmation_sheet.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/widgets/driver_navigation_view.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  for (final demo in ['none', 'new', 'restored', 'stale']) {
    for (final failFirstTransition in [false, true]) {
      testWidgets(
        'pickup enters delivery without another step; demo=$demo retry=$failFirstTransition',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = failFirstTransition
              ? const Size(320, 568)
              : demo == 'new'
              ? const Size(900, 700)
              : const Size(390, 844);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final png = (await tester.runAsync(() async {
            final recorder = ui.PictureRecorder();
            Canvas(recorder).drawColor(Colors.white, BlendMode.src);
            final picture = recorder.endRecording();
            final image = await picture.toImage(1, 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            image.dispose();
            picture.dispose();
            return bytes!.buffer.asUint8List();
          }))!;
          await http.runWithClient(
            () async {
              final now = DateTime.now().toUtc();
              final events = <String>[];
              final orders = _Orders(events, failFirstTransition);
              final proof = _Proof(events);
              final sessions = DriverNavSessionsNotifier();
              await sessions.hydrate();
              if (demo != 'new') {
                await sessions.upsert(
                  DriverNavSession(
                    orderId: 'order',
                    status: 'assigned',
                    lat: 10.771,
                    lng: 106.703,
                    locationMode: DriverLocationMode.demoHcm,
                    arrivedAtTarget: demo == 'stale',
                  ),
                );
              }
              final container = ProviderContainer(
                overrides: [
                  customerOrderServiceProvider.overrideWithValue(orders),
                  deliveryProofServiceProvider.overrideWithValue(proof),
                  driverNavSessionsProvider.overrideWith((ref) => sessions),
                  driverLocationModeProvider.overrideWith(
                    (ref) => DriverLocationMode.demoHcm,
                  ),
                  driverByUserIdProvider.overrideWith((ref, id) async => null),
                  currentPositionProvider.overrideWith((ref) async => null),
                  realtimeServiceProvider.overrideWithValue(_Location()),
                  locationIngestServiceProvider.overrideWithValue(_Location()),
                  driverWalletSummaryProvider.overrideWith(
                    (ref) async => const DriverWalletSummary(
                      availableBalance: 100000,
                      heldBalance: 0,
                      todayIncome: 0,
                    ),
                  ),
                  driverCancellationRepositoryProvider.overrideWithValue(
                    DriverCancellationRepository(
                      invoke: (name, params) async {
                        if (name != 'confirm_driver_pickup_arrival' ||
                            orders.status != 'picking_up') {
                          throw StateError('Invalid pickup arrival transition');
                        }
                        final location = LatLng(
                          params['p_lat'] as double,
                          params['p_lng'] as double,
                        );
                        if (const Distance(roundResult: false)(
                              location,
                              const LatLng(10.773, 106.703),
                            ) >
                            100) {
                          throw const PostgrestException(
                            message: 'PICKUP_OUTSIDE_GEOFENCE',
                            code: '23514',
                          );
                        }
                        events.add('pickup-arrival');
                        return {'pickup_arrived_at': now.toIso8601String()};
                      },
                    ),
                  ),
                ],
              );
              addTearDown(() async {
                await tester.pumpWidget(const SizedBox.shrink());
                await tester.pump(const Duration(milliseconds: 1));
                container.dispose();
              });
              await tester.pumpWidget(
                UncontrolledProviderScope(
                  container: container,
                  child: MaterialApp(
                    home: DriverNavigationScreen(
                      order: OrderModel(
                        id: 'order',
                        customerId: 'customer',
                        driverId: 'driver',
                        status: 'assigned',
                        pickupAddress: 'Điểm lấy',
                        pickupLat: 10.773,
                        pickupLng: 106.703,
                        deliveryAddress: 'Điểm giao',
                        deliveryLat: 10.776,
                        deliveryLng: 106.701,
                        createdAt: now,
                        updatedAt: now,
                        trackingCode: 'GH-FOUR',
                        deliveryFee: 30000,
                        serviceType: 'standard',
                        paymentMethod: 'cash',
                        trafficDemoKey: demo == 'none' ? null : 'off_peak',
                        deliveryEtaData: demo == 'none'
                            ? null
                            : {
                                'driver_id': 'driver',
                                'calculation_mode': 'assignment_once_v1',
                                'approach': _leg(
                                  const LatLng(10.771, 106.703),
                                  const LatLng(10.773, 106.703),
                                ),
                                'delivery': _leg(
                                  const LatLng(10.773, 106.703),
                                  const LatLng(10.776, 106.701),
                                ),
                              },
                        estimatedDeliveryAt: now.add(
                          const Duration(minutes: 30),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              DriverNavigationView view() =>
                  tester.widget<DriverNavigationView>(
                    find.byType(DriverNavigationView),
                  );
              for (
                var tick = 0;
                tick < 20 && view().onStartSimulation == null;
                tick++
              ) {
                await tester.pump(const Duration(milliseconds: 10));
              }
              expect(find.text('Đã đến điểm lấy hàng'), findsOneWidget);
              expect(find.text('Gạt để đến nơi lấy hàng'), findsNothing);
              expect(view().simulationRunning, isFalse);
              expect(view().arrivedAtTarget, isFalse);
              await tester.pump(const Duration(seconds: 2));
              expect(view().driverLatitude, 10.771);
              expect(view().onStartSimulation, isNotNull);
              view().onStartSimulation!();
              await tester.pump(const Duration(seconds: 20));
              expect(view().arrivedAtTarget, isTrue);
              expect(view().routeCompleted, isFalse);
              final arrivedLatitude = view().driverLatitude;
              view().onConfirmPickupArrival!();
              await tester.pumpAndSettle();
              expect(view().order.status, 'picking_up');
              expect(
                events,
                ['status:assigned', 'pickup-arrival'],
                reason: tester
                    .widgetList<Text>(find.byType(Text))
                    .map((text) => text.data)
                    .where((text) => text?.startsWith('Lỗi') == true)
                    .join('\n'),
              );
              expect(view().order.pickupArrivedAt, now);
              expect(view().driverLatitude, arrivedLatitude);
              expect(view().simulationRunning, isFalse);
              expect(find.text('Đã lấy hàng'), findsOneWidget);
              view().onPrimaryAction!();
              await tester.pumpAndSettle();
              Navigator.of(tester.element(find.byType(BottomSheet))).pop(
                DriverDeliveryConfirmationResult(
                  proof: DeliveryProofCapture(
                    image: XFile.fromData(
                      Uint8List.fromList([1]),
                      name: 'proof.png',
                      mimeType: 'image/png',
                    ),
                    capturedAt: now,
                    location: DeliveryProofLocation(
                      latitude: view().driverLatitude!,
                      longitude: view().driverLongitude!,
                    ),
                    address: 'Điểm lấy',
                  ),
                ),
              );
              await tester.pumpAndSettle();
              if (failFirstTransition) {
                expect(view().order.status, 'picking_up');
                expect(view().pickupConfirmed, isTrue);
                expect(view().simulationRunning, isFalse);
                view().onPrimaryAction!();
                await tester.pumpAndSettle();
              }
              expect(view().order.status, 'delivering');
              expect(proof.submissions, 1);
              expect(view().simulationRunning, isFalse);
              expect(find.text('Gạt để bắt đầu giao'), findsNothing);
              await tester.pump(const Duration(seconds: 2));
              expect(view().driverLatitude, arrivedLatitude);
              expect(
                container.read(driverNavSessionsProvider)['order']?.status,
                'delivering',
              );
              expect(view().onStartSimulation, isNotNull);
              view().onStartSimulation!();
              await tester.pump(const Duration(seconds: 90));
              expect(view().arrivedAtTarget, isTrue);
              expect(view().routeCompleted, isTrue);
              await view().onPrepareDeliveryArrival!();
              view().onPrimaryAction!();
              await tester.pumpAndSettle();
              Navigator.of(tester.element(find.byType(BottomSheet))).pop(
                DriverDeliveryConfirmationResult(
                  proof: DeliveryProofCapture(
                    image: XFile.fromData(
                      Uint8List.fromList([1]),
                      name: 'delivery.png',
                      mimeType: 'image/png',
                    ),
                    capturedAt: now,
                    location: DeliveryProofLocation(
                      latitude: view().driverLatitude!,
                      longitude: view().driverLongitude!,
                    ),
                    address: 'Điểm giao',
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(view().order.status, 'delivered');
              expect(proof.submissions, 2);
              expect(
                events,
                containsAllInOrder([
                  'proof:pickup',
                  'status:picking_up',
                  'proof:delivery',
                  'status:delivering',
                ]),
              );
              expect(
                container.read(driverNavSessionsProvider).containsKey('order'),
                isFalse,
              );
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump(const Duration(milliseconds: 1));
              expect(tester.takeException(), isNull);
            },
            () => MockClient((request) async {
              if (request.url.path.endsWith('.png')) {
                return http.Response.bytes(
                  png,
                  200,
                  headers: {'content-type': 'image/png'},
                );
              }
              return http.Response('', 503);
            }),
          );
        },
      );
    }
  }
}

Map<String, dynamic> _leg(LatLng start, LatLng end) {
  final meters = const Distance(roundResult: false)(start, end);
  return {
    'distance_meters': meters,
    'forecast_at': '2026-10-13T00:00:00Z',
    'route_points': [
      [start.longitude, start.latitude],
      [end.longitude, end.latitude],
    ],
    'speed_profile': [
      {'start_meters': 0, 'end_meters': meters, 'speed_kmh': 25},
    ],
  };
}

class _Orders implements CustomerOrderService {
  _Orders(this.events, this.failOnce);
  final List<String> events;
  bool failOnce;
  String status = 'assigned';
  @override
  Future<String> updateDriverOrderStatus({
    required String orderId,
    required String driverId,
    required String currentStatus,
  }) async {
    if (currentStatus != status) {
      throw StateError('Order status did not match the server');
    }
    events.add('status:$currentStatus');
    if (currentStatus == 'picking_up' && failOnce) {
      failOnce = false;
      throw StateError('network');
    }
    return status = switch (currentStatus) {
      'assigned' => 'picking_up',
      'picking_up' => 'delivering',
      'delivering' => 'delivered',
      _ => throw StateError('Invalid status'),
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Proof implements DeliveryProofService {
  _Proof(this.events);
  final List<String> events;
  int submissions = 0;
  @override
  Future<DeliveryProofModel> submitProof({
    required String orderId,
    required String driverId,
    required DeliveryProofStage stage,
    required XFile image,
    DateTime? capturedAt,
    double? capturedLat,
    double? capturedLng,
  }) async {
    final target = stage == DeliveryProofStage.pickup
        ? const LatLng(10.773, 106.703)
        : const LatLng(10.776, 106.701);
    if (capturedLat == null ||
        capturedLng == null ||
        const Distance(roundResult: false)(
              LatLng(capturedLat, capturedLng),
              target,
            ) >
            100) {
      throw StateError('HANDOFF_OUTSIDE_GEOFENCE');
    }
    submissions++;
    events.add('proof:${stage.value}');
    return DeliveryProofModel(
      id: 'proof',
      orderId: orderId,
      driverId: driverId,
      stage: stage,
      storagePath: 'proof.png',
      capturedAt: capturedAt!,
    );
  }

  @override
  Future<void> confirmPickup({required String orderId}) async =>
      events.add('pickup-retry');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Location implements LocationIngestService, RealtimeService {
  @override
  Future<void> broadcastDriverLocation({
    required String orderId,
    required double lat,
    required double lng,
    double? speedKmh,
  }) async {}
  @override
  Future<void> ingest({
    String? driverProfileId,
    String? driverUserId,
    String? orderId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
    double? accuracy,
    DateTime? capturedAt,
    LatLng? monitoringPosition,
    bool force = false,
    bool prioritySync = false,
    LocationIngestCoordinateSpace coordinateSpace =
        LocationIngestCoordinateSpace.rawGps,
  }) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
