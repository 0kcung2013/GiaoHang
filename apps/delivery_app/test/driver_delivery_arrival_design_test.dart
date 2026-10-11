import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_delivery_wait_card.dart';
import 'package:delivery_app/features/driver/screens/navigation/utils/driver_delivery_arrival_strings.dart';
import 'package:delivery_app/features/risk_reports/widgets/risk_reason_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  testWidgets('recipient report opens at ten minutes, never before', (
    tester,
  ) async {
    var calls = 0;
    Future<void> show(Duration elapsed) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverDeliveryWaitCard(
            isNearDelivery: true,
            confirmedWait: elapsed,
            onReportRecipient: () => calls++,
          ),
        ),
      ),
    );
    await show(const Duration(minutes: 9, seconds: 59));
    expect(find.text('Chờ thêm 0:01'), findsOneWidget);
    await tester.tap(find.text(DriverDeliveryArrivalStrings.reportRecipient));
    expect(calls, 0);
    await show(const Duration(minutes: 10));
    await tester.tap(find.text(DriverDeliveryArrivalStrings.reportRecipient));
    expect(calls, 1);
  });

  testWidgets('driver reasons show only common pickup incidents', (
    tester,
  ) async {
    RiskCategory? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RiskReasonStep(
              role: RiskReporterRole.driver,
              selected: null,
              errorText: null,
              onSelected: (value) => chosen = value,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Vấn đề thanh toán'), findsNothing);
    expect(find.text('Hàng không đúng thông tin'), findsOneWidget);
    expect(find.text('Không thể nhận hàng'), findsOneWidget);
    await tester.tap(find.text('Sự cố khác'));
    expect(chosen, RiskCategory.other);
  });

  testWidgets('waiting states fit short mobile with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final elapsed in [
      null,
      const Duration(minutes: 3),
      const Duration(minutes: 10),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: DriverDeliveryWaitCard(
                  isNearDelivery: false,
                  confirmedWait: elapsed,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
