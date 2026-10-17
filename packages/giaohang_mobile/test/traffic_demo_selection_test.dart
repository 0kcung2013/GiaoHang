import 'dart:io';
import 'dart:ui' as ui;
import 'package:giaohang_mobile/core/models/recent_address_model.dart';
import 'package:giaohang_mobile/core/services/osrm_service.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/controllers/order_map_picker_controller.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/create_order_screen.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/models/traffic_demo_scenario.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/utils/traffic_demo_strings.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/map_picker_sheet.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/order_location_step.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/traffic_demo_route_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'helpers/utraffic_capture_fonts.dart';
import 'support/return_map_test_tiles.dart';

const peak = TrafficDemoScenario.hcmHistoricCongestion;
const offPeak = TrafficDemoScenario.hcmHistoricClearTraffic;
const changedDelivery = LatLng(10.855, 106.743);
const changedPickup = LatLng(10.841, 106.741);

MapPickerResult selection(LatLng point, String address) => MapPickerResult(
  position: point,
  formattedAddress: address,
  addressDetail: '',
  deliveryNote: '',
);

OrderLocationStep step(WidgetTester tester) =>
    tester.widget<OrderLocationStep>(find.byType(OrderLocationStep));

Future<void> chooseTime(
  WidgetTester tester,
  TrafficDemoScenario scenario,
) async {
  await tester.tap(find.byKey(ValueKey('traffic-demo-route-${scenario.id}')));
  await tester.pumpAndSettle();
  expect(step(tester).quotedAt.isAtSameMomentAs(scenario.forecastAt), isTrue);
  expect(
    tester
        .widget<TrafficDemoRouteSelector>(find.byType(TrafficDemoRouteSelector))
        .selectedId,
    scenario.id,
  );
}

Future<void> openScreen(
  WidgetTester tester,
  OrderMapPickerController picker, {
  GlobalKey? capture,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: capture,
      child: ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: CreateOrderScreen(
              mapPicker: picker,
              osrm: _NoRoute(),
              tileProvider: ReturnMapTestTiles(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await ReturnMapTestTiles.prepare();
    await prepareUtrafficCaptureFonts();
  });

  testWidgets(
    'sample route and forecast time are independent after editing and cancelling pins',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final picker = _Picker([
        selection(changedDelivery, 'Điểm giao tự chọn'),
        null,
        selection(changedPickup, 'Điểm lấy tự chọn'),
      ]);
      await openScreen(tester, picker);
      await tester.tap(find.byKey(const ValueKey('traffic-demo-sample-route')));
      await tester.pumpAndSettle();
      expect(step(tester).pickup, peak.pickup);
      expect(step(tester).delivery, peak.delivery);
      expect(step(tester).quotedAt.isAtSameMomentAs(peak.forecastAt), isTrue);

      await chooseTime(tester, offPeak);
      await tester.tap(find.text(peak.deliveryAddress));
      await tester.pumpAndSettle();
      expect(step(tester).delivery, changedDelivery);
      expect(
        step(tester).quotedAt.isAtSameMomentAs(offPeak.forecastAt),
        isTrue,
      );
      await chooseTime(tester, peak);
      expect(step(tester).delivery, changedDelivery);
      expect(step(tester).pickup, peak.pickup);

      await tester.tap(find.text(peak.pickupAddress));
      await tester.pumpAndSettle();
      expect(step(tester).pickup, peak.pickup);
      expect(step(tester).delivery, changedDelivery);
      expect(step(tester).quotedAt.isAtSameMomentAs(peak.forecastAt), isTrue);
      await tester.tap(find.text(peak.pickupAddress));
      await tester.pumpAndSettle();
      expect(step(tester).pickup, changedPickup);
      expect(step(tester).quotedAt.isAtSameMomentAs(peak.forecastAt), isTrue);
      await chooseTime(tester, offPeak);
      expect(step(tester).pickup, changedPickup);
      expect(step(tester).delivery, changedDelivery);

      await tester.tap(find.byKey(const ValueKey('traffic-demo-sample-route')));
      await tester.pumpAndSettle();
      expect(step(tester).pickup, peak.pickup);
      expect(step(tester).delivery, peak.delivery);
      expect(
        step(tester).quotedAt.isAtSameMomentAs(offPeak.forecastAt),
        isTrue,
      );
      expect(picker.calls, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final config in [
    (const Size(390, 760), 1.0),
    (const Size(320, 600), 1.6),
  ]) {
    testWidgets(
      'custom route stays selected when choosing hours; compact form at ${config.$1}',
      (tester) async {
        await tester.binding.setSurfaceSize(config.$1);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final capture = GlobalKey();
        final picker = _Picker([
          selection(changedPickup, peak.pickupAddress),
          selection(
            changedDelivery,
            '1, Hẻm 22/49 Đường 22, Khu phố 47, Thành phố Hồ Chí Minh',
          ),
        ]);
        await openScreen(
          tester,
          picker,
          capture: capture,
          textScale: config.$2,
        );
        step(tester).onPickPickup();
        await tester.pumpAndSettle();
        step(tester).onPickDelivery();
        await tester.pumpAndSettle();
        await chooseTime(tester, peak);
        await chooseTime(tester, offPeak);
        expect(step(tester).pickup, changedPickup);
        expect(step(tester).delivery, changedDelivery);
        expect(find.text(TrafficDemoStrings.sampleRouteLabel), findsOneWidget);
        expect(find.textContaining('Mô phỏng lấy'), findsNothing);
        expect(find.textContaining('ETA cập nhật'), findsNothing);
        expect(find.text(TrafficDemoStrings.forecastNote), findsNothing);
        expect(find.textContaining(' km'), findsNothing);
        expect(find.text('Tiếp tục'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('ETA_SIMULATION_CAPTURE')) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              '../../output/eta_simulation/ui/compact-picker-${config.$1.width.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

class _Picker extends OrderMapPickerController {
  _Picker(this.responses);
  final List<MapPickerResult?> responses;
  int calls = 0;

  @override
  Future<OrderMapPickerOutcome> pick({
    required BuildContext context,
    required RecentAddressType addressType,
    required MapPickerResult? currentSelection,
    required Position? currentPosition,
    required Future<Position?> Function() locate,
  }) async => OrderMapPickerOutcome(
    selection: responses[calls++],
    currentPosition: currentPosition,
    usedFallback: false,
  );
}

class _NoRoute extends OsrmService {
  @override
  Future<OsrmRouteResult?> getRouteWithWaypoints({
    required List<LatLng> waypoints,
  }) async => null;
}
