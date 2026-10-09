import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/risk_reports/constants/risk_report_strings.dart';
import 'package:operations_web/features/risk_reports/models/risk_report.dart';
import 'package:operations_web/features/risk_reports/widgets/risk_case_conversation.dart';
import 'package:operations_web/features/risk_reports/widgets/risk_report_detail_body.dart';

void main() {
  for (final viewport in [
    (size: const Size(375, 568), scale: 1.6),
    (size: const Size(882, 849), scale: 1.0),
    (size: const Size(1280, 850), scale: 1.0),
  ]) {
    testWidgets(
      'support review fits ${viewport.size} scale ${viewport.scale}',
      (tester) async {
        tester.view.physicalSize = viewport.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(viewport.scale)),
              child: child!,
            ),
            home: Scaffold(body: _body()),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Hàng quá lớn so với xe, cần đổi tài xế.'),
          findsOneWidget,
        );
        expect(find.text('Hủy đơn cho Tài xế'), findsOneWidget);
        expect(find.text('Ghi chú nội bộ'), findsNothing);
        expect(find.text('Nội bộ'), findsNothing);
        expect(find.text('Lịch sử xử lý'), findsOneWidget);
        expect(find.text('GH-10180'), findsNothing);
        await tester.ensureVisible(find.text('Thông tin đơn và liên hệ'));
        await tester.tap(find.text('Thông tin đơn và liên hệ'));
        await tester.pumpAndSettle();
        expect(find.text('GH-10180'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Thông tin đơn và liên hệ'));
        await tester.tap(find.text('Thông tin đơn và liên hệ'));
        await tester.pumpAndSettle();
        final scroll = find.byType(SingleChildScrollView).first;
        await tester.scrollUntilVisible(
          find.text('Hủy đơn cho Tài xế'),
          150,
          scrollable: find
              .descendant(of: scroll, matching: find.byType(Scrollable))
              .first,
        );
        await tester.tap(find.text('Hủy đơn cho Tài xế'));
        await tester.pumpAndSettle();
        expect(find.text('Hủy đơn cho Tài xế?'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('driver cancellation needs confirmation without a handoff form', (
    tester,
  ) async {
    RiskInterventionState? decision;
    var released = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _body(
            orderStatus: 'picking_up',
            onHoldBeforePickup: () async => released = true,
            onDecision: (value, text) async {
              decision = value;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gỡ tài xế, giữ đơn'), findsNothing);
    expect(find.text('Hủy đơn cho Tài xế'), findsOneWidget);
    expect(find.text('Bàn giao, đổi tài xế'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('release-driver-button')));
    await tester.tap(find.byKey(const Key('release-driver-button')));
    await tester.pumpAndSettle();
    expect(find.text('Hủy đơn cho Tài xế?'), findsOneWidget);
    expect(find.byKey(const Key('risk-operation-instruction')), findsNothing);
    expect(find.byKey(const Key('risk-operation-recipient')), findsNothing);
    expect(find.byKey(const Key('risk-operation-destination')), findsNothing);
    expect(decision, isNull);
    expect(released, isFalse);
    await tester.tap(find.byKey(const Key('confirm-risk-operation')));
    await tester.pumpAndSettle();
    expect(decision, isNull);
    expect(released, isTrue);
  });

  for (final viewport in [
    (size: const Size(375, 568), scale: 1.6),
    (size: const Size(1280, 850), scale: 1.0),
  ]) {
    testWidgets('cancel confirmation can be dismissed at ${viewport.size}', (
      tester,
    ) async {
      tester.view.physicalSize = viewport.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(viewport.scale)),
            child: child!,
          ),
          home: Scaffold(
            body: _body(
              orderStatus: 'picking_up',
              onHoldBeforePickup: () async {
                calls++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Hủy đơn cho Tài xế'));
      await tester.tap(find.text('Hủy đơn cho Tài xế'));
      await tester.pumpAndSettle();
      expect(find.text('Hủy đơn cho Tài xế?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Quay lại'));
      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.text('Hủy đơn cho Tài xế?'), findsNothing);
      expect(calls, 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final state in [
    (status: 'delivering', pickedUpAt: null),
    (status: 'picking_up', pickedUpAt: DateTime.utc(2026, 10, 8)),
  ]) {
    testWidgets('received cargo uses returns for ${state.status}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _body(
              orderStatus: state.status,
              actualPickedUpAt: state.pickedUpAt,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hủy đơn cho Tài xế'), findsNothing);
      expect(find.byKey(const Key('return-order-button')), findsOneWidget);
      expect(find.byKey(const Key('handoff-order-button')), findsNothing);
    });
  }

  testWidgets('legacy handoff before pickup can be corrected by support', (
    tester,
  ) async {
    var released = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _body(
            orderStatus: 'picking_up',
            interventionState: RiskInterventionState.handoffRequired,
            onHoldBeforePickup: () async => released = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Xác nhận đã giải quyết hàng hóa'), findsNothing);
    await tester.ensureVisible(find.text('Hủy đơn cho Tài xế'));
    await tester.tap(find.text('Hủy đơn cho Tài xế'));
    await tester.pumpAndSettle();
    expect(
      find.text(RiskReportStrings.cancelDriverConfirmation),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('confirm-risk-operation')));
    await tester.pumpAndSettle();
    expect(released, isTrue);
  });

  for (final status in [RiskStatus.resolved, RiskStatus.investigating]) {
    testWidgets(
      'blocks changes on ${status.name} report owned by another staff',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _body(status: status, owner: 'other-staff'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('release-driver-button')), findsNothing);
        expect(find.byKey(const Key('risk-case-message-field')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('support replies publicly without an internal-note selector', (
    tester,
  ) async {
    CaseMessageVisibility? sentVisibility;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiskCaseConversation(
            messages: const [],
            currentUserId: 'staff',
            canReply: true,
            publicRecipient: 'tài xế',
            allowInternal: false,
            onSend: (_, visibility) async => sentVisibility = visibility,
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('risk-case-message-field')),
      'Đã kiểm tra, CSKH sẽ đổi tài xế.',
    );
    await tester.tap(find.byKey(const Key('send-risk-case-message')));
    await tester.pumpAndSettle();
    expect(sentVisibility, CaseMessageVisibility.public);
    expect(find.byType(SegmentedButton<CaseMessageVisibility>), findsNothing);
  });
}

Widget _body({
  String orderStatus = 'assigned',
  RiskStatus status = RiskStatus.investigating,
  String owner = 'staff',
  DateTime? actualPickedUpAt,
  RiskInterventionState interventionState =
      RiskInterventionState.awaitingTriage,
  Future<void> Function()? onHoldBeforePickup,
  Future<void> Function(RiskInterventionState, String?)? onDecision,
}) {
  final report = RiskReport(
    id: 'risk',
    orderId: 'order',
    reportedBy: 'driver',
    assignedTo: owner,
    category: RiskCategory.cargoIssue,
    severity: RiskSeverity.medium,
    status: status,
    title: 'Hàng hóa có vấn đề',
    description: 'Hàng quá lớn so với xe, cần đổi tài xế.',
    resolution: null,
    createdAt: DateTime(2026, 10, 8),
    updatedAt: DateTime(2026, 10, 8),
    reporterRole: RiskReporterRole.driver,
    reporterName: 'Nguyễn Văn An',
    order: RiskOrderSummary(
      trackingCode: 'GH-10180',
      status: orderStatus,
      actualPickedUpAt: actualPickedUpAt,
      pickupAddress: 'Kho trung tâm',
      deliveryAddress: 'Điểm giao',
    ),
  );
  return RiskReportDetailBody(
    report: report,
    currentUserId: 'staff',
    criticalRestricted: false,
    intervention: RiskIntervention(
      riskReportId: 'risk',
      orderId: 'order',
      state: interventionState,
      driverId: 'driver',
      decisionDueAt: DateTime(2026, 10, 8),
      instruction: null,
      driverReleasedAt: null,
    ),
    notes: const [],
    attachments: const [],
    messageEvidence: const [],
    availableMessages: const [],
    evidenceLoading: false,
    attachingEvidence: false,
    onAttachEvidence: (_) async {},
    caseMessages: const [],
    canReply: owner == 'staff' && !status.isClosed,
    onSendMessage: (_, _) async {},
    events: const [],
    error: null,
    onHoldBeforePickup: onHoldBeforePickup ?? () async {},
    onDecision: onDecision ?? (_, _) async {},
    onApproveReturn: (_) async {},
    onConfirmCustody: () async {},
    onResumeOrder: () async {},
    onAddNote: (_) async {},
  );
}
