import 'package:delivery_app/features/returns/widgets/customer_return_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  testWidgets('customer sees live return status and transparent charge', (
    tester,
  ) async {
    final mission = _mission(
      status: OrderReturnStatus.returning,
      feePayer: ReturnFeePayer.customer,
      customerCharge: 28000,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CustomerReturnStatusBanner(mission: mission)),
      ),
    );

    expect(find.text('Tài xế đang hoàn hàng'), findsOneWidget);
    expect(find.text('Phí khách trả'), findsOneWidget);
    expect(find.text('28.000đ'), findsOneWidget);

    await tester.tap(find.text('Xem chi tiết'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết hoàn đơn'), findsOneWidget);
    expect(find.text('Khách hàng'), findsOneWidget);
  });

  test('return model round-trips database values', () {
    final original = _mission(
      status: OrderReturnStatus.approved,
      feePayer: ReturnFeePayer.platform,
      customerCharge: 0,
    );
    final decoded = OrderReturn.fromJson(original.toJson());

    expect(decoded.status, OrderReturnStatus.approved);
    expect(decoded.destinationType, ReturnDestinationType.sender);
    expect(decoded.feePayer, ReturnFeePayer.platform);
    expect(decoded.canStart, isTrue);
  });
}

OrderReturn _mission({
  required OrderReturnStatus status,
  required ReturnFeePayer feePayer,
  required int customerCharge,
}) {
  final now = DateTime(2026, 8, 16);
  return OrderReturn(
    id: 'return-1',
    orderId: 'order-1',
    riskReportId: 'risk-1',
    driverId: 'driver-1',
    status: status,
    destinationType: ReturnDestinationType.sender,
    destinationAddress: '12 Nguyễn Huệ, Quận 1',
    destinationLat: 10.77,
    destinationLng: 106.70,
    routeOriginLat: 10.78,
    routeOriginLng: 106.71,
    routeDistanceMeters: 4200,
    routeDurationSeconds: 900,
    quoteSource: ReturnQuoteSource.osrm,
    reasonCode: 'delivery_incident',
    feePayer: feePayer,
    customerReturnCharge: customerCharge,
    driverReturnEarning: 28000,
    feeStatus: ReturnFeeStatus.approved,
    approvedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}
