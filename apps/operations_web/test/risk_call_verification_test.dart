import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/risk_reports/models/risk_report.dart';
import 'package:operations_web/features/risk_reports/widgets/risk_call_verification_card.dart';

void main() {
  for (final outcome in ['Không nghe máy', 'Máy bận', 'Có trả lời']) {
    testWidgets('demo call can simulate $outcome without leaving the case', (
      tester,
    ) async {
      await _pumpCard(tester);
      expect(find.text('Demo'), findsOneWidget);
      expect(find.text('Mô phỏng cuộc gọi, không gọi thật.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('risk-call-scenario')));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .ancestor(
              of: find.text(outcome),
              matching: find.byWidgetPredicate(
                (widget) => widget is CheckedPopupMenuItem,
              ),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('risk-call-demo')));
      await tester.pump();
      expect(find.text('Đang đổ chuông…'), findsOneWidget);
      expect(
        tester
            .widget<PopupMenuButton>(
              find.byKey(const Key('risk-call-scenario')),
            )
            .enabled,
        isFalse,
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Demo · $outcome'), findsOneWidget);
      expect(find.text('Gọi lại demo'), findsOneWidget);
      expect(find.text('Demo'), findsOneWidget);
    });
  }

  testWidgets('stopping the demo does not create a missed-call result', (
    tester,
  ) async {
    await _pumpCard(tester);
    await tester.tap(find.byKey(const Key('risk-call-demo')));
    await tester.pump();
    await tester.tap(find.text('Dừng gọi'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Đã dừng cuộc gọi'), findsOneWidget);
    expect(find.text('Demo · Không nghe máy'), findsNothing);
    await tester.tap(find.byKey(const Key('risk-call-demo')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing contacts clears the previous demo result', (
    tester,
  ) async {
    await _pumpCard(tester);
    await tester.tap(find.byKey(const Key('risk-call-demo')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Demo · Không nghe máy'), findsOneWidget);
    await tester.tap(find.byKey(const Key('risk-call-contact')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khách đặt đơn'));
    await tester.pumpAndSettle();
    expect(find.text('0909000002'), findsOneWidget);
    expect(find.text('Demo · Không nghe máy'), findsNothing);
    expect(find.text('Gọi demo'), findsOneWidget);
  });

  testWidgets('a different case and revoked access cancel an ongoing demo', (
    tester,
  ) async {
    await _pumpCard(tester);
    await tester.tap(find.byKey(const Key('risk-call-demo')));
    await tester.pump();
    await _pumpCard(tester, report: _report(id: 'other-risk'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Demo · Không nghe máy'), findsNothing);
    await tester.tap(find.byKey(const Key('risk-call-demo')));
    await tester.pump();
    await _pumpCard(tester, report: _report(id: 'other-risk'), enabled: false);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Demo · Không nghe máy'), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('risk-call-demo')))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'missing phone disables the demo without inventing contact data',
    (tester) async {
      await _pumpCard(tester, report: _report(hasPhone: false));
      expect(find.text('Chưa có số điện thoại'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('risk-call-demo')))
            .onPressed,
        isNull,
      );
    },
  );

  for (final size in [const Size(320, 568), const Size(1280, 850)]) {
    testWidgets('call controls fit $size with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpCard(tester, scale: 1.6);
      await tester.tap(find.byKey(const Key('risk-call-demo')));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Demo · Không nghe máy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpCard(
  WidgetTester tester, {
  RiskReport? report,
  bool enabled = true,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: RiskCallVerificationCard(
                report: report ?? _report(),
                enabled: enabled,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

RiskReport _report({String id = 'risk', bool hasPhone = true}) => RiskReport(
  id: id,
  orderId: 'order',
  reportedBy: 'driver',
  assignedTo: 'staff',
  category: RiskCategory.contactIssue,
  severity: RiskSeverity.medium,
  status: RiskStatus.investigating,
  title: 'Khách không nghe máy',
  description: 'Đã chờ 10 phút.',
  resolution: null,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  reporterRole: RiskReporterRole.driver,
  order: RiskOrderSummary(
    trackingCode: 'GH-10195',
    status: 'delivering',
    pickupAddress: 'Kho trung tâm',
    deliveryAddress: 'Điểm giao',
    recipientName: 'Trần Thu Hà',
    recipientPhone: hasPhone ? '0909000001' : null,
    customer: RiskContact(
      name: 'Nguyễn Văn Bình',
      phone: hasPhone ? '0909000002' : null,
    ),
  ),
);
