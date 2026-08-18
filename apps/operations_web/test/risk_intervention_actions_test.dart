import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/risk_reports/models/risk_report.dart';
import 'package:operations_web/features/risk_reports/widgets/risk_report_actions.dart';
import 'package:operations_web/features/risk_reports/widgets/risk_intervention_panel.dart';

void main() {
  testWidgets('locks manual report status while driver is returning cargo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiskReportActionBar(
            assignedToMe: true,
            unassigned: false,
            submitting: false,
            statusLocked: true,
            transitions: const [RiskStatus.investigating],
            onAssign: () {},
            onTransition: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.text('Trạng thái được khóa khi tài xế đang hoàn hàng'),
      findsWidgets,
    );
    expect(find.text('Đang xác minh'), findsNothing);
  });

  testWidgets('acceptance is separate from pre-pickup hold', (tester) async {
    var held = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiskInterventionPanel(
            report: _report(status: RiskStatus.open),
            intervention: _intervention(RiskInterventionState.awaitingTriage),
            orderStatus: 'assigned',
            onHoldBeforePickup: () async => held = true,
            onDecision: (_, _) async {},
            onConfirmCustody: () async {},
            onResumeOrder: () async {},
            onAddNote: (_) async {},
          ),
        ),
      ),
    );

    expect(
      find.text('Tiếp nhận báo cáo trước khi can thiệp đơn.'),
      findsOneWidget,
    );
    expect(find.text('Giữ đơn & giải phóng tài xế'), findsNothing);
    expect(held, isFalse);
  });

  testWidgets('assigned order can be explicitly held and release driver', (
    tester,
  ) async {
    var held = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiskInterventionPanel(
            report: _report(),
            intervention: _intervention(RiskInterventionState.awaitingTriage),
            orderStatus: 'assigned',
            onHoldBeforePickup: () async => held = true,
            onDecision: (_, _) async {},
            onConfirmCustody: () async {},
            onResumeOrder: () async {},
            onAddNote: (_) async {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Giữ đơn & giải phóng tài xế'));
    await tester.pumpAndSettle();
    expect(held, isFalse);
    await tester.tap(find.byKey(const Key('confirm-risk-operation')));
    await tester.pumpAndSettle();
    expect(held, isTrue);
  });

  testWidgets('return decision requires a custom instruction', (tester) async {
    RiskInterventionState? decision;
    String? instruction;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiskInterventionPanel(
            report: _report(),
            intervention: _intervention(RiskInterventionState.awaitingTriage),
            orderStatus: 'delivering',
            onHoldBeforePickup: () async {},
            onDecision: (value, text) async {
              decision = value;
              instruction = text;
            },
            onConfirmCustody: () async {},
            onResumeOrder: () async {},
            onAddNote: (_) async {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Yêu cầu hoàn trả'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pump();
    expect(find.text('Vui lòng nhập hướng dẫn.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('risk-operation-instruction')),
      'Hoàn hàng tại kho trung tâm.',
    );
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(decision, RiskInterventionState.returnRequired);
    expect(instruction, 'Hoàn hàng tại kho trung tâm.');
  });

  testWidgets('renders staff-only note history', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiskInterventionPanel(
            report: _report(),
            intervention: _intervention(RiskInterventionState.continueDelivery),
            orderStatus: 'delivering',
            notes: [
              RiskReportNote(
                id: 'note-1',
                riskReportId: 'risk-1',
                authorId: 'staff-1',
                body: 'Đã gọi xác minh với khách hàng.',
                createdAt: DateTime(2026),
                authorName: 'CSKH An',
              ),
            ],
            onHoldBeforePickup: () async {},
            onDecision: (_, _) async {},
            onConfirmCustody: () async {},
            onResumeOrder: () async {},
            onAddNote: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('Đã gọi xác minh với khách hàng.'), findsOneWidget);
    expect(find.textContaining('CSKH An'), findsOneWidget);
  });

  testWidgets('keeps an empty note composer collapsed until requested', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiskInterventionPanel(
            report: _report(),
            intervention: _intervention(RiskInterventionState.continueDelivery),
            orderStatus: 'delivering',
            onHoldBeforePickup: () async {},
            onDecision: (_, _) async {},
            onConfirmCustody: () async {},
            onResumeOrder: () async {},
            onAddNote: (_) async {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('risk-internal-note')), findsNothing);
    await tester.tap(find.text('Ghi chú nội bộ'));
    await tester.pump();
    expect(find.byKey(const Key('risk-internal-note')), findsOneWidget);
  });

  testWidgets('blocks intervention when another staff owns the report', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiskInterventionPanel(
            report: _report(),
            intervention: _intervention(RiskInterventionState.awaitingTriage),
            orderStatus: 'delivering',
            canManage: false,
            managementBlockedMessage: 'Hồ sơ đang do CSKH Bình phụ trách.',
            onHoldBeforePickup: () async {},
            onDecision: (_, _) async {},
            onConfirmCustody: () async {},
            onResumeOrder: () async {},
            onAddNote: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('Hồ sơ đang do CSKH Bình phụ trách.'), findsOneWidget);
    expect(find.text('Tiếp tục giao'), findsNothing);
    expect(find.byKey(const Key('risk-internal-note')), findsNothing);
  });
}

RiskReport _report({RiskStatus status = RiskStatus.investigating}) =>
    RiskReport(
      id: 'risk-1',
      orderId: 'order-1',
      reportedBy: 'customer-1',
      assignedTo: 'staff-1',
      category: RiskCategory.safety,
      severity: RiskSeverity.medium,
      status: status,
      title: 'Vấn đề an toàn',
      description: 'Khu vực giao hàng không an toàn.',
      resolution: null,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      order: const RiskOrderSummary(
        trackingCode: 'GH123',
        status: 'delivering',
        pickupAddress: 'Điểm lấy',
        deliveryAddress: 'Điểm giao',
      ),
    );

RiskIntervention _intervention(RiskInterventionState state) => RiskIntervention(
  riskReportId: 'risk-1',
  orderId: 'order-1',
  state: state,
  driverId: 'driver-1',
  decisionDueAt: DateTime(2026),
  instruction: null,
  driverReleasedAt: null,
);
