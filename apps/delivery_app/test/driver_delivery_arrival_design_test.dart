import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_delivery_wait_card.dart';
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
    await tester.tap(find.text('Không liên lạc được với khách'));
    expect(calls, 0);
    await show(const Duration(minutes: 10));
    await tester.tap(find.text('Không liên lạc được với khách'));
    expect(calls, 1);
  });

  testWidgets('compact driver reasons retain payment and other', (
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
    expect(find.text('Tai nạn / mất an toàn'), findsOneWidget);
    await tester.tap(find.text('Thanh toán / sự cố khác'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Vấn đề thanh toán'));
    await tester.tap(find.text('Vấn đề thanh toán'));
    expect(chosen, RiskCategory.payment);
    expect(find.text('Vấn đề khác'), findsOneWidget);
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
