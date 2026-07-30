import 'package:customer_app/core/models/order_model.dart';
import 'package:customer_app/features/customer/widgets/order_assignment_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderModel assignment timeout', () {
    final createdAt = DateTime.utc(2026, 7, 29, 8);

    test('uses the server deadline while the assignment window is open', () {
      final deadline = createdAt.add(const Duration(minutes: 15));
      final order = _order(createdAt: createdAt, assignmentExpiresAt: deadline);

      expect(
        order.isAwaitingDriverAt(createdAt.add(const Duration(minutes: 14))),
        isTrue,
      );
      expect(
        order.isAssignmentTimedOutAt(
          createdAt.add(const Duration(minutes: 14)),
        ),
        isFalse,
      );
      expect(
        order.effectiveStatusAt(createdAt.add(const Duration(minutes: 14))),
        'pending',
      );
    });

    test('becomes assignment_timeout exactly at the server deadline', () {
      final deadline = createdAt.add(const Duration(minutes: 15));
      final order = _order(createdAt: createdAt, assignmentExpiresAt: deadline);

      expect(order.isAwaitingDriverAt(deadline), isFalse);
      expect(order.isAssignmentTimedOutAt(deadline), isTrue);
      expect(order.effectiveStatusAt(deadline), 'assignment_timeout');
    });

    test(
      'server timeout marker remains authoritative after a clock rollback',
      () {
        final deadline = createdAt.add(const Duration(minutes: 15));
        final order = _order(
          createdAt: createdAt,
          assignmentExpiresAt: deadline,
          assignmentTimedOutAt: deadline,
        );

        expect(
          order.isAssignmentTimedOutAt(
            createdAt.add(const Duration(minutes: 10)),
          ),
          isTrue,
        );
      },
    );

    test('an assigned order is never treated as timed out', () {
      final order = _order(
        createdAt: createdAt,
        status: 'assigned',
        driverId: 'driver-1',
        assignmentExpiresAt: createdAt.add(const Duration(minutes: 15)),
      );

      expect(
        order.isAssignmentTimedOutAt(createdAt.add(const Duration(hours: 1))),
        isFalse,
      );
      expect(
        order.effectiveStatusAt(createdAt.add(const Duration(hours: 1))),
        'assigned',
      );
    });

    test('parses assignment timestamps returned by Supabase', () {
      final order = OrderModel.fromJson({
        ..._order(createdAt: createdAt).toJson(),
        'assignment_expires_at': '2026-07-29T08:15:00.000Z',
        'assignment_timed_out_at': '2026-07-29T08:15:01.000Z',
      });

      expect(order.assignmentExpiresAt, DateTime.utc(2026, 7, 29, 8, 15));
      expect(order.assignmentTimedOutAt, DateTime.utc(2026, 7, 29, 8, 15, 1));
    });
  });

  group('OrderAssignmentStatusCard', () {
    testWidgets('shows a live countdown while waiting for a driver', (
      tester,
    ) async {
      final now = DateTime.now();
      final order = _order(
        createdAt: now,
        assignmentExpiresAt: now.add(const Duration(minutes: 10)),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: OrderAssignmentStatusCard(order: order)),
          ),
        ),
      );

      expect(find.text('Đang tìm tài xế'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              RegExp(r'^\d{2}:\d{2}$').hasMatch(widget.data ?? ''),
        ),
        findsOneWidget,
      );
      expect(find.text('Tìm lại'), findsNothing);
    });

    testWidgets('shows retry and cancel actions after timeout', (tester) async {
      final now = DateTime.now();
      final deadline = now.subtract(const Duration(seconds: 1));
      final order = _order(
        createdAt: now.subtract(const Duration(minutes: 16)),
        assignmentExpiresAt: deadline,
        assignmentTimedOutAt: deadline,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: OrderAssignmentStatusCard(order: order)),
          ),
        ),
      );

      expect(find.text('Chưa tìm thấy tài xế'), findsOneWidget);
      expect(find.text('Tìm lại'), findsOneWidget);
      expect(find.text('Hủy đơn'), findsOneWidget);
    });
  });
}

OrderModel _order({
  required DateTime createdAt,
  String status = 'pending',
  String? driverId,
  DateTime? assignmentExpiresAt,
  DateTime? assignmentTimedOutAt,
}) {
  return OrderModel(
    id: 'order-1',
    customerId: 'customer-1',
    driverId: driverId,
    status: status,
    pickupAddress: 'Điểm lấy hàng',
    pickupLat: 10.7,
    pickupLng: 106.6,
    deliveryAddress: 'Điểm giao hàng',
    deliveryLat: 10.8,
    deliveryLng: 106.7,
    createdAt: createdAt,
    trackingCode: 'GH-00001',
    assignmentExpiresAt: assignmentExpiresAt,
    assignmentTimedOutAt: assignmentTimedOutAt,
    deliveryFee: 30000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    updatedAt: createdAt,
  );
}
