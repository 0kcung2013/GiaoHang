import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:delivery_app/core/location/driver_location_producer_policy.dart';
import 'package:delivery_app/core/location/location_ingest_service.dart';
import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/providers/customer_providers.dart';
import 'package:delivery_app/core/providers/driver_nav_session_provider.dart';
import 'package:delivery_app/core/providers/location_providers.dart';
import 'package:delivery_app/core/services/realtime_service.dart';
import 'package:delivery_app/features/driver/screens/navigation/driver_navigation_screen.dart';
import 'package:delivery_app/features/returns/data/order_return_repository.dart';
import 'package:delivery_app/features/returns/driver_return_navigation_screen.dart';
import 'package:delivery_app/features/returns/widgets/return_navigation_map.dart';
import 'package:delivery_app/features/returns/widgets/return_bottom_panel.dart';
import 'package:delivery_app/features/driver/widgets/driver_swipe_action.dart';
import 'package:delivery_app/features/returns/return_map_screen.dart';
import 'package:delivery_app/features/returns/models/return_redelivery_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _origin = LatLng(10.775, 106.680);
const _destination = LatLng(10.785, 106.690);
final _created = DateTime.utc(2026, 10, 9);
final _order = OrderModel.fromJson({
  'id': 'return-order',
  'driver_id': 'driver',
  'customer_id': 'customer',
  'status': 'returning',
  'pickup_address': 'Điểm lấy',
  'delivery_address': 'Điểm giao',
  'pickup_lat': _origin.latitude,
  'pickup_lng': _origin.longitude,
  'delivery_lat': _destination.latitude,
  'delivery_lng': _destination.longitude,
  'tracking_code': 'GH-RETURN',
  'created_at': _created.toIso8601String(),
});
final _mission = OrderReturn.fromJson({
  'id': 'return-mission',
  'order_id': _order.id,
  'risk_report_id': 'risk',
  'driver_id': 'driver',
  'status': 'returning',
  'destination_type': 'sender',
  'destination_address': 'Điểm trả hàng',
  'destination_lat': _destination.latitude,
  'destination_lng': _destination.longitude,
  'route_origin_lat': _origin.latitude,
  'route_origin_lng': _origin.longitude,
  'route_distance_m': 1600,
  'route_duration_s': 300,
  'approved_at': _created.toIso8601String(),
  'started_at': _created.toIso8601String(),
  'created_at': _created.toIso8601String(),
  'updated_at': _created.toIso8601String(),
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_prepareTestFonts);
  tearDownAll(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null),
  );
  for (final scenario in [
    (
      name: 'cached profile',
      restart: false,
      staleProfile: false,
      visitDelivery: false,
    ),
    (
      name: 'delayed position sync',
      restart: false,
      staleProfile: true,
      visitDelivery: false,
    ),
    (
      name: 'app restart before position sync',
      restart: true,
      staleProfile: true,
      visitDelivery: false,
    ),
    (
      name: 'old delivery map opens between returns',
      restart: false,
      staleProfile: true,
      visitDelivery: true,
    ),
  ]) {
    testWidgets(
      'return stays at handoff after reopening: ${scenario.name}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = scenario.staleProfile
            ? const Size(320, 568)
            : const Size(390, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final client = (await tester.runAsync(
          () async => SupabaseClient(
            'https://example.supabase.co',
            'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        ))!;
        addTearDown(client.dispose);
        var persistedPosition = _origin;
        var profileReads = 0;
        final ingest = _Ingest(client, (point) => persistedPosition = point);
        final realtime = _Realtime(client);
        ProviderContainer createContainer() => ProviderContainer(
          overrides: [
            driverByUserIdProvider.overrideWith((ref, id) async {
              profileReads++;
              final profilePosition = scenario.staleProfile
                  ? _origin
                  : persistedPosition;
              return DriverModel(
                id: 'profile',
                userId: 'driver',
                isAvailable: false,
                currentLat: profilePosition.latitude,
                currentLng: profilePosition.longitude,
                updatedAt: _created,
                totalDeliveries: 0,
              );
            }),
            driverLocationModeProvider.overrideWith(
              (ref) => DriverLocationMode.demoHcm,
            ),
            currentPositionProvider.overrideWith((ref) async => null),
            locationIngestServiceProvider.overrideWith((ref) => ingest),
            realtimeServiceProvider.overrideWith((ref) => realtime),
          ],
        );
        var container = createContainer();
        addTearDown(() => container.dispose());
        addTearDown(ingest.dispose);
        addTearDown(realtime.dispose);
        final png = (await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          ui.Canvas(recorder).drawColor(Colors.white, ui.BlendMode.src);
          final picture = recorder.endRecording();
          final image = await picture.toImage(1, 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          picture.dispose();
          return bytes!.buffer.asUint8List();
        }))!;
        final transport = MockClient(
          (request) async => request.url.host.contains('tile.')
              ? http.Response.bytes(
                  png,
                  200,
                  headers: {'content-type': 'image/png'},
                )
              : http.Response('', 503),
        );
        addTearDown(transport.close);
        final repository = _Repository(
          failCancellation: scenario.name == 'delayed position sync',
        );
        ReturnRedeliveryResult? redelivery;
        var firstMount = true;
        await http.runWithClient(() async {
          Future<void> mount() async {
            final startsApproved =
                scenario.name == 'cached profile' && firstMount;
            firstMount = false;
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(
                        scenario.staleProfile ? 1.6 : 1,
                      ),
                    ),
                    child: child!,
                  ),
                  home: Builder(
                    builder: (context) => Scaffold(
                      body: FilledButton(
                        key: const Key('open-return-test'),
                        onPressed: () async {
                          final result = await Navigator.of(context)
                              .push<Object?>(
                                MaterialPageRoute(
                                  builder: (_) => DriverReturnNavigationScreen(
                                    order: _order,
                                    mission: startsApproved
                                        ? OrderReturn.fromJson({
                                            ..._mission.toJson(),
                                            'status': 'approved',
                                          })
                                        : _mission,
                                    repository: repository,
                                  ),
                                ),
                              );
                          if (result is ReturnRedeliveryResult) {
                            redelivery = result;
                          }
                        },
                        child: const Text('Open return'),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.byKey(const Key('open-return-test')));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));
            for (var tick = 0; tick < 10; tick++) {
              await tester.pump(const Duration(milliseconds: 1));
              await tester.runAsync(() async {
                await Future<void>.delayed(Duration.zero);
              });
              await tester.pump();
              if (!tester
                  .widget<ReturnBottomPanel>(find.byType(ReturnBottomPanel))
                  .loading) {
                break;
              }
            }
            final panel = tester.widget<ReturnBottomPanel>(
              find.byType(ReturnBottomPanel),
            );
            expect(panel.loading, isFalse, reason: panel.error);
          }

          // Tạo cache profile trước khi tài xế bắt đầu di chuyển.
          await container.read(driverByUserIdProvider('driver').future);
          await tester.runAsync(
            () => container.read(driverNavSessionsProvider.notifier).ready,
          );
          await mount();
          if (tester
              .widget<ReturnBottomPanel>(find.byType(ReturnBottomPanel))
              .mission
              .canStart) {
            await tester.drag(
              find.byKey(const Key('return-primary-action')),
              const Offset(500, 0),
            );
            await tester.pump(const Duration(milliseconds: 350));
            expect(
              tester
                  .widget<ReturnBottomPanel>(find.byType(ReturnBottomPanel))
                  .mission
                  .status,
              OrderReturnStatus.returning,
            );
          }
          // Niêm phong hành vi mới: mount/chờ/mở MAP không tự chạy GPS.
          expect(find.byType(ReturnNavigationMap), findsNothing);
          expect(find.text('Lấy'), findsOneWidget);
          expect(find.text('Giao'), findsOneWidget);
          await tester.pump(const Duration(seconds: 3));
          expect(persistedPosition, _origin);
          await tester.ensureVisible(find.byKey(const Key('return-open-map')));
          await tester.tap(find.byKey(const Key('return-open-map')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.byType(ReturnBottomPanel), findsNothing);
          expect(find.byType(DriverSwipeAction), findsNothing);
          await tester.pump(const Duration(seconds: 3));
          expect(
            tester
                .widget<ReturnNavigationMap>(find.byType(ReturnNavigationMap))
                .position,
            _origin,
          );
          await tester.tap(find.byKey(const Key('return-map-start')));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump();
          final firstMovement = tester
              .widget<ReturnNavigationMap>(find.byType(ReturnNavigationMap))
              .position!;
          expect(firstMovement, isNot(_origin));
          expect(firstMovement, isNot(_destination));
          expect(
            tester
                .widget<ReturnNavigationMap>(find.byType(ReturnNavigationMap))
                .route!
                .first,
            _origin,
            reason: 'Keep the geometry for animation.',
          );
          // Vào bán kính xác nhận vẫn tiếp tục chạy GPS, không nhảy 150 m cuối.
          await tester.pump(const Duration(seconds: 97));
          final nearHandoff = tester
              .widget<ReturnNavigationMap>(find.byType(ReturnNavigationMap))
              .position!;
          expect(
            const Distance(
              roundResult: false,
            ).as(LengthUnit.Meter, nearHandoff, _destination),
            lessThan(150),
          );
          expect(nearHandoff, isNot(_destination));
          expect(
            tester
                .widget<ReturnMapScreen>(find.byType(ReturnMapScreen))
                .snapshot
                .value
                .running,
            isTrue,
          );
          // GPS mô phỏng đi hết tuyến thay vì nhảy thẳng tới đỉnh cuối.
          await tester.pump(const Duration(seconds: 30));
          await tester.pump(const Duration(seconds: 2));
          expect(
            tester
                .widget<ReturnNavigationMap>(find.byType(ReturnNavigationMap))
                .position,
            _destination,
          );
          expect(persistedPosition, _destination);
          expect(tester.takeException(), isNull, reason: 'MAP sau khi Start');
          await tester.tap(find.byKey(const Key('return-map-back')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.byType(ReturnNavigationMap), findsNothing);
          expect(find.byType(ReturnBottomPanel), findsOneWidget);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 1));
          if (scenario.visitDelivery) {
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  home: DriverNavigationScreen(
                    order: _order.copyWith(status: 'delivering'),
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 1));
            await tester.runAsync(() async {
              await Future<void>.delayed(Duration.zero);
            });
            await tester.pump(const Duration(seconds: 2));
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(milliseconds: 1));
            final saved = container.read(driverNavSessionsProvider)[_order.id]!;
            expect(saved.status, 'returning');
            expect(LatLng(saved.lat, saved.lng), _destination);
          }
          if (scenario.restart) {
            container.dispose();
            container = createContainer();
            await tester.runAsync(
              () => container.read(driverNavSessionsProvider.notifier).ready,
            );
          }
          await mount();
          await tester.ensureVisible(find.byKey(const Key('return-open-map')));
          await tester.tap(find.byKey(const Key('return-open-map')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(
            tester
                .widget<ReturnNavigationMap>(find.byType(ReturnNavigationMap))
                .position,
            _destination,
          );
          await tester.pump(const Duration(seconds: 3));
          expect(
            tester
                .widget<ReturnNavigationMap>(find.byType(ReturnNavigationMap))
                .position,
            _destination,
          );
          final snapshot = tester
              .widget<ReturnMapScreen>(find.byType(ReturnMapScreen))
              .snapshot
              .value;
          expect(snapshot.distance, 0);
          expect(snapshot.duration, 0);
          expect(profileReads, greaterThanOrEqualTo(2));
          await tester.tap(find.byKey(const Key('return-map-back')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          await tester.ensureVisible(
            find.byKey(const Key('return-delivery-tab')),
          );
          await tester.tap(find.byKey(const Key('return-delivery-tab')));
          await tester.pump();
          expect(
            tester
                .widget<DriverSwipeAction>(
                  find.byKey(const Key('return-delivery-disabled')),
                )
                .onCompleted,
            isNull,
          );
          await tester.tap(find.byKey(const Key('return-cancel')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('return-confirm-redelivery')));
          await tester.pumpAndSettle();
          if (repository.failCancellation) {
            expect(redelivery, isNull);
            expect(
              tester
                  .widget<ReturnBottomPanel>(find.byType(ReturnBottomPanel))
                  .mission
                  .status,
              OrderReturnStatus.returning,
            );
          } else {
            expect(redelivery?.order.status, 'delivering');
            expect(redelivery?.position, _destination);
            expect(
              container.read(driverNavSessionsProvider).containsKey(_order.id),
              isFalse,
            );
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 1));
          expect(tester.takeException(), isNull);
        }, () => transport);
      },
      timeout: const Timeout(Duration(seconds: 45)),
    );
  }
}

class _Ingest extends LocationIngestService {
  _Ingest(SupabaseClient client, this.save) : super(client: client) {
    // Fake chỉ ghi nhận payload; không chạy queue và timer nền của service thật.
    unawaited(super.dispose());
  }
  final void Function(LatLng) save;
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
  }) async => save(LatLng(lat, lng));
}

class _Realtime extends RealtimeService {
  _Realtime(SupabaseClient client) : super(client: client);
  @override
  Future<void> broadcastDriverLocation({
    required String orderId,
    required double lat,
    required double lng,
  }) async {}
}

class _Repository
    implements OrderReturnRepository, OrderReturnRedeliveryRepository {
  _Repository({this.failCancellation = false});
  final bool failCancellation;
  @override
  Future<bool> canCancelReturn(String orderId) async => true;
  @override
  Future<OrderReturn> cancelReturn({
    required String orderId,
    required String reason,
  }) async {
    if (failCancellation) throw StateError('offline');
    return OrderReturn.fromJson({..._mission.toJson(), 'status': 'cancelled'});
  }

  @override
  Future<OrderReturn?> fetchForOrder(String id) async => _mission;
  @override
  Future<(double, double)?> fetchIncidentOrigin(String id) async =>
      (_origin.latitude, _origin.longitude);
  @override
  Stream<OrderReturn?> watchForOrder(String id) => Stream.value(_mission);
  @override
  Future<OrderReturn> startReturn(String id) async => _mission;
  @override
  Future<OrderReturn> confirmReturn({
    required String orderId,
    required String receiverName,
    String? note,
  }) async => _mission;
}

Future<void> _prepareTestFonts() async {
  // Dùng font test có sẵn trong Flutter SDK, không phụ thuộc mạng hoặc ổ máy.
  final configFile = File('../../.dart_tool/package_config.json');
  final config =
      jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
  final flutterPackage = (config['packages'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((package) => package['name'] == 'flutter');
  final flutterPackageUri = configFile.absolute.uri.resolve(
    '${flutterPackage['rootUri']}/',
  );
  final font = await File.fromUri(
    flutterPackageUri.resolve('../flutter_tools/static/Ahem.ttf'),
  ).readAsBytes();
  final marker = await File(
    'assets/images/delivery_scooter_marker.svg',
  ).readAsBytes();
  const variants = [
    'Thin',
    'ExtraLight',
    'Light',
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
    'Black',
  ];
  final manifest = <String, Object>{
    for (final family in ['PlusJakartaSans', 'JetBrainsMono'])
      for (final variant in variants)
        'fonts/$family-$variant.ttf': [
          {'asset': 'fonts/$family-$variant.ttf'},
        ],
  };
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        if (key == 'AssetManifest.bin') {
          return const StandardMessageCodec().encodeMessage(manifest);
        }
        if (key == 'assets/images/delivery_scooter_marker.svg') {
          return ByteData.sublistView(marker);
        }
        return manifest.containsKey(key) ? ByteData.sublistView(font) : null;
      });
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final weight in FontWeight.values) {
    GoogleFonts.plusJakartaSans(fontWeight: weight);
    GoogleFonts.jetBrainsMono(fontWeight: weight);
  }
  await GoogleFonts.pendingFonts();
}
