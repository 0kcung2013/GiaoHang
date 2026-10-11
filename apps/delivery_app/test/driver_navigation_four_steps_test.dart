import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:delivery_app/core/location/driver_location_producer_policy.dart';
import 'package:delivery_app/core/location/location_ingest_service.dart';
import 'package:delivery_app/core/models/delivery_proof_model.dart';
import 'package:delivery_app/core/models/driver_wallet.dart';
import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/providers/customer_providers.dart';
import 'package:delivery_app/core/providers/driver_nav_session_provider.dart';
import 'package:delivery_app/core/providers/driver_wallet_providers.dart';
import 'package:delivery_app/core/providers/location_providers.dart';
import 'package:delivery_app/core/services/customer_order_service.dart';
import 'package:delivery_app/core/services/delivery_proof_service.dart';
import 'package:delivery_app/core/services/delivery_proof_watermark_service.dart';
import 'package:delivery_app/core/services/realtime_service.dart';
import 'package:delivery_app/features/driver/cancellation/data/driver_cancellation_repository.dart';
import 'package:delivery_app/features/driver/cancellation/driver_cancellation_providers.dart';
import 'package:delivery_app/features/driver/screens/navigation/driver_navigation_screen.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_delivery_confirmation_sheet.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_navigation_view.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  for (final failFirstTransition in [false, true]) {
    testWidgets(
      'pickup enters delivery without another step; retry=$failFirstTransition',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = failFirstTransition
            ? const Size(320, 568)
            : const Size(390, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final png = (await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawColor(Colors.white, BlendMode.src);
          final picture = recorder.endRecording();
          final image = await picture.toImage(1, 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
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
            await sessions.upsert(
              DriverNavSession(
                orderId: 'order',
                status: 'assigned',
                lat: 10.771,
                lng: 106.703,
                locationMode: DriverLocationMode.demoHcm,
              ),
            );
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
                      estimatedDeliveryAt: now.add(const Duration(minutes: 30)),
                    ),
                  ),
                ),
              ),
            );
            DriverNavigationView view() => tester.widget<DriverNavigationView>(
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
            await tester.pump(const Duration(seconds: 2));
            expect(view().driverLatitude, 10.771);
            expect(view().onStartSimulation, isNotNull);
            view().onStartSimulation!();
            await tester.pump(const Duration(seconds: 20));
            expect(view().arrivedAtTarget, isTrue);
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
                  location: const DeliveryProofLocation(
                    latitude: 10.773,
                    longitude: 106.703,
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
            expect(view().driverLatitude, 10.773);
            expect(
              container.read(driverNavSessionsProvider)['order']?.status,
              'delivering',
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
    return status = currentStatus == 'assigned' ? 'picking_up' : 'delivering';
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
