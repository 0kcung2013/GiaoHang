import 'package:delivery_app/features/returns/utils/return_completion_guard.dart';
import 'package:delivery_app/features/returns/widgets/return_bottom_panel.dart';
import 'package:delivery_app/features/driver/widgets/driver_swipe_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  group('ReturnCompletionGuard', () {
    test('reproduces the reported 786 meter geofence rejection', () {
      final distance = ReturnCompletionGuard.distanceMeters(
        currentLat: 11.0307940034249,
        currentLng: 106.622002625703,
        destinationLat: 11.0349584266544,
        destinationLng: 106.616181922547,
      );

      expect(distance, inInclusiveRange(785, 787));
      expect(ReturnCompletionGuard.canComplete(distance), isFalse);
    });

    test('accepts a position at the 150 meter boundary', () {
      expect(ReturnCompletionGuard.canComplete(150), isTrue);
      expect(ReturnCompletionGuard.canComplete(150.01), isFalse);
      expect(ReturnCompletionGuard.canComplete(null), isFalse);
    });

    test('maps geofence PostgREST error to actionable Vietnamese copy', () {
      final message = ReturnCompletionGuard.userMessage(
        Exception(
          'PostgrestException(message: RETURN_OUTSIDE_GEOFENCE, code: 23514)',
        ),
      );

      expect(message, contains('phạm vi 150 m'));
      expect(message, isNot(contains('PostgrestException')));
      expect(message, isNot(contains('23514')));
    });
  });

  group('ReturnBottomPanel', () {
    testWidgets('allows swiping before arrival and explains photo validation', (
      tester,
    ) async {
      var actionCount = 0;
      await tester.pumpWidget(
        _testApp(handoffDistance: 786, onAction: () => actionCount++),
      );

      expect(find.textContaining('786 m'), findsOneWidget);
      expect(find.byType(DriverSwipeAction), findsOneWidget);
      expect(find.textContaining('Gạt để mở xác nhận ảnh'), findsOneWidget);
      await _completeSwipe(
        tester,
        find.byKey(const Key('return-primary-action')),
      );
      expect(actionCount, 1);
    });

    testWidgets('enables confirmation inside the return geofence', (
      tester,
    ) async {
      var actionCount = 0;
      await tester.pumpWidget(
        _testApp(handoffDistance: 120, onAction: () => actionCount++),
      );

      await _completeSwipe(
        tester,
        find.byKey(const Key('return-primary-action')),
      );
      expect(actionCount, 1);
    });

    testWidgets('fits a compact phone with large text', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _testApp(
          handoffDistance: 786,
          onAction: () {},
          textScaler: const TextScaler.linear(1.6),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the map-first panel compact on a 375x667 phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_testApp(handoffDistance: 786, onAction: () {}));

      final panel = find.byKey(const Key('return-bottom-panel'));
      expect(panel, findsOneWidget);
      expect(tester.getSize(panel).height, lessThanOrEqualTo(200));
    });
  });
}

Future<void> _completeSwipe(WidgetTester tester, Finder finder) async {
  final rect = tester.getRect(finder);
  final gesture = await tester.startGesture(
    Offset(rect.left + 24, rect.center.dy),
  );
  await gesture.moveTo(Offset(rect.right - 24, rect.center.dy));
  await gesture.up();
  await tester.pumpAndSettle();
}

Widget _testApp({
  required double? handoffDistance,
  required VoidCallback onAction,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ReturnBottomPanel(
            mission: _mission(),
            loading: false,
            submitting: false,
            distance: 1100,
            duration: 180,
            handoffDistance: handoffDistance,
            error: null,
            onRefresh: () {},
            onAction: onAction,
          ),
        ),
      ),
    ),
  );
}

OrderReturn _mission() => OrderReturn.fromJson({
  'id': 'return-1',
  'order_id': 'order-1',
  'risk_report_id': 'risk-1',
  'driver_id': 'driver-1',
  'status': 'returning',
  'destination_type': 'sender',
  'destination_address': '123 Huỳnh Thị Hiếu, Thành phố Hồ Chí Minh',
  'destination_lat': 11.0349584266544,
  'destination_lng': 106.616181922547,
  'route_origin_lat': 11.03,
  'route_origin_lng': 106.62,
  'route_distance_m': 1100,
  'route_duration_s': 180,
  'quote_source': 'osrm',
  'reason_code': 'recipient_refused',
  'fee_payer': 'platform',
  'customer_return_charge': 0,
  'driver_return_earning': 179000,
  'fee_status': 'waived',
  'approved_at': '2026-08-17T04:40:00Z',
  'started_at': '2026-08-17T04:42:00Z',
  'created_at': '2026-08-17T04:40:00Z',
  'updated_at': '2026-08-17T04:42:00Z',
});
