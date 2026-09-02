import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/risk_reports/data/risk_report_repository.dart';
import 'package:operations_web/features/risk_reports/dialogs/risk_report_detail_dialog.dart';
import 'package:operations_web/features/risk_reports/models/risk_message_evidence.dart';
import 'package:operations_web/features/risk_reports/models/risk_report.dart';
import 'package:operations_web/features/risk_reports/widgets/risk_report_detail_body.dart';

void main() {
  testWidgets('risk report detail loads message evidence for its order', (
    tester,
  ) async {
    final repository = _EvidenceRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiskReportDetailDialog(
            report: _report,
            currentUserId: 'staff-1',
            isAdmin: true,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tin nhắn bằng chứng'), findsOneWidget);
    expect(find.text('Tài xế xác nhận đang chờ.'), findsOneWidget);
    expect(find.text('Ảnh và vị trí'), findsOneWidget);
    expect(find.text('Chưa thể xác định địa chỉ cụ thể'), findsOneWidget);
    expect(find.text('Mở bản đồ'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(repository.requestedOrderId, 'order-1');
    expect(repository.requestedReportId, 'risk-1');
  });

  testWidgets('detail shows reporter identity next to submitted evidence', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiskReportDetailBody(
            report: _reportWithProfile,
            currentUserId: 'staff-1',
            criticalRestricted: false,
            intervention: null,
            notes: const [],
            attachments: const [],
            messageEvidence: const [],
            availableMessages: const [],
            evidenceLoading: false,
            attachingEvidence: false,
            onAttachEvidence: (_) async {},
            caseMessages: const [],
            canReply: true,
            onSendMessage: (_, _) async {},
            events: const [],
            error: null,
            onHoldBeforePickup: () async {},
            onDecision: (_, _) async {},
            onApproveReturn: (_) async {},
            onConfirmCustody: () async {},
            onResumeOrder: () async {},
            onAddNote: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('Nguyễn An'), findsOneWidget);
    expect(find.text('0901234567'), findsOneWidget);
    expect(find.text('an@example.com'), findsOneWidget);
    expect(find.text('Người gửi báo cáo'), findsOneWidget);
    expect(
      find.byKey(const Key('risk-reporter-profile-avatar')),
      findsOneWidget,
    );
    expect(find.text('Trao đổi và lịch sử'), findsOneWidget);
    expect(find.text('Lịch sử xử lý'), findsNothing);

    await tester.ensureVisible(find.text('Trao đổi và lịch sử'));
    await tester.tap(find.text('Trao đổi và lịch sử'));
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử xử lý'), findsOneWidget);
  });

  testWidgets('first delivery decision accepts an unassigned report inline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _DirectDecisionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiskReportDetailDialog(
            report: _unassignedReport,
            currentUserId: 'staff-1',
            isAdmin: false,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nhận và bắt đầu xác minh'), findsNothing);
    expect(find.byKey(const Key('continue-delivery-button')), findsOneWidget);
    await tester.ensureVisible(find.text('Ghi chú nội bộ'));
    await tester.tap(find.text('Ghi chú nội bộ'));
    await tester.pump();
    expect(find.byKey(const Key('risk-internal-note')), findsNothing);

    await tester.tap(find.byKey(const Key('continue-delivery-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-risk-operation')));
    await tester.pumpAndSettle();

    expect(repository.operations, ['accept', 'continue_delivery']);
  });

  testWidgets('retrying a failed decision does not accept the report twice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _DirectDecisionRepository(failFirstDecision: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiskReportDetailDialog(
            report: _unassignedReport,
            currentUserId: 'staff-1',
            isAdmin: false,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(find.byKey(const Key('continue-delivery-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-risk-operation')));
      await tester.pumpAndSettle();
    }

    expect(repository.operations, [
      'accept',
      'continue_delivery',
      'continue_delivery',
    ]);
  });

  testWidgets('non-delivery report offers a direct status action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _DirectDecisionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiskReportDetailDialog(
            report: _unassignedPendingReport,
            currentUserId: 'staff-1',
            isAdmin: false,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nhận và bắt đầu xác minh'), findsNothing);
    expect(find.text('Đang xác minh'), findsOneWidget);
    await tester.tap(find.text('Đang xác minh'));
    await tester.pumpAndSettle();

    expect(repository.operations, ['accept', 'status:investigating']);
  });
}

final _report = RiskReport(
  id: 'risk-1',
  orderId: 'order-1',
  reportedBy: 'staff-1',
  assignedTo: 'staff-1',
  category: RiskCategory.safety,
  severity: RiskSeverity.high,
  status: RiskStatus.investigating,
  title: 'Xác minh liên lạc',
  description: 'Cần kiểm tra nội dung trao đổi của đơn hàng.',
  resolution: null,
  createdAt: DateTime(2026, 8, 8, 9),
  updatedAt: DateTime(2026, 8, 8, 10),
  order: const RiskOrderSummary(
    trackingCode: 'GH-00001',
    status: 'delivering',
    pickupAddress: 'Điểm lấy',
    deliveryAddress: 'Điểm giao',
  ),
);

final _reportWithProfile = RiskReport(
  id: 'risk-profile',
  orderId: 'order-1',
  reportedBy: 'customer-1',
  assignedTo: 'staff-1',
  category: RiskCategory.contactIssue,
  severity: RiskSeverity.medium,
  status: RiskStatus.investigating,
  title: 'Không liên lạc được',
  description: 'Người nhận chưa phản hồi.',
  resolution: null,
  createdAt: DateTime(2026, 8, 8, 9),
  updatedAt: DateTime(2026, 8, 8, 10),
  reporterRole: RiskReporterRole.customer,
  reporterName: 'Nguyễn An',
  reporterAvatarUrl: 'https://example.com/avatar.jpg',
  reporterPhone: '0901234567',
  reporterEmail: 'an@example.com',
  order: const RiskOrderSummary(
    trackingCode: 'GH-00001',
    status: 'delivering',
    pickupAddress: 'Điểm lấy',
    deliveryAddress: 'Điểm giao',
  ),
);

final _unassignedReport = RiskReport(
  id: 'risk-unassigned',
  orderId: 'order-1',
  reportedBy: 'customer-1',
  assignedTo: null,
  category: RiskCategory.contactIssue,
  severity: RiskSeverity.medium,
  status: RiskStatus.open,
  title: 'Không liên lạc được',
  description: 'Người nhận chưa phản hồi.',
  resolution: null,
  createdAt: DateTime(2026, 8, 8, 9),
  updatedAt: DateTime(2026, 8, 8, 10),
  reporterRole: RiskReporterRole.customer,
  reporterName: 'Nguyễn An',
  order: const RiskOrderSummary(
    trackingCode: 'GH-00001',
    status: 'delivering',
    pickupAddress: 'Điểm lấy',
    deliveryAddress: 'Điểm giao',
  ),
);

final _unassignedPendingReport = RiskReport(
  id: 'risk-pending',
  orderId: 'order-pending',
  reportedBy: 'customer-1',
  assignedTo: null,
  category: RiskCategory.contactIssue,
  severity: RiskSeverity.medium,
  status: RiskStatus.open,
  title: 'Cần kiểm tra đơn mới',
  description: 'Khách hàng cần hỗ trợ trước khi giao.',
  resolution: null,
  createdAt: DateTime(2026, 8, 8, 9),
  updatedAt: DateTime(2026, 8, 8, 10),
  reporterRole: RiskReporterRole.customer,
  reporterName: 'Nguyễn An',
  order: const RiskOrderSummary(
    trackingCode: 'GH-00002',
    status: 'pending',
    pickupAddress: 'Điểm lấy',
    deliveryAddress: 'Điểm giao',
  ),
);

class _EvidenceRepository
    implements RiskReportRepository, RiskReportAttachmentRepository {
  String? requestedOrderId;
  String? requestedReportId;

  @override
  Future<List<RiskOrderMessage>> fetchOrderMessages(String orderId) async {
    requestedOrderId = orderId;
    return const [];
  }

  @override
  Future<List<RiskMessageEvidence>> fetchMessageEvidence(
    String reportId,
  ) async {
    requestedReportId = reportId;
    return [
      RiskMessageEvidence(
        id: 'evidence-1',
        riskReportId: 'risk-1',
        sourceMessageId: 'message-1',
        orderId: 'order-1',
        senderId: 'driver-1',
        body: 'Tài xế xác nhận đang chờ.',
        sentAt: DateTime(2026, 8, 8, 9, 30),
        isQuickReply: true,
        addedBy: 'staff-1',
        createdAt: DateTime(2026, 8, 8, 10),
      ),
    ];
  }

  @override
  Future<List<RiskMessageEvidence>> attachMessageEvidence(
    String reportId,
    List<String> messageIds,
  ) async => fetchMessageEvidence(reportId);

  @override
  Future<void> assignToMe(String reportId) async {}

  @override
  Future<void> changeStatus(
    String reportId,
    RiskStatus status, {
    String? resolution,
  }) async {}

  @override
  Future<void> createReport(RiskReportDraft draft) async {}

  @override
  Future<List<RiskReportEvent>> fetchEvents(String reportId) async => [];

  @override
  Future<List<RiskReport>> fetchReports() async => [];

  @override
  Future<List<RiskReportAttachmentView>> fetchAttachments(
    String reportId,
  ) async {
    return [
      RiskReportAttachmentView(
        attachment: RiskReportAttachment.fromJson({
          'id': 'photo-1',
          'risk_report_id': reportId,
          'order_id': 'order-1',
          'evidence_type': 'photo',
          'storage_path': 'user/risk/photo.jpg',
          'created_at': '2026-08-08T10:00:00Z',
        }),
        signedUrl: 'https://example.com/photo.jpg',
      ),
      RiskReportAttachmentView(
        attachment: RiskReportAttachment.fromJson({
          'id': 'location-1',
          'risk_report_id': reportId,
          'order_id': 'order-1',
          'evidence_type': 'location',
          'latitude': 10.7765,
          'longitude': 106.7009,
          'created_at': '2026-08-08T10:00:00Z',
        }),
      ),
    ];
  }
}

class _DirectDecisionRepository
    implements RiskReportRepository, RiskInterventionCommandRepository {
  _DirectDecisionRepository({this.failFirstDecision = false});

  final List<String> operations = [];
  final bool failFirstDecision;
  var _decisionAttempts = 0;

  @override
  Future<RiskIntervention?> fetchIntervention(String reportId) async =>
      RiskIntervention(
        riskReportId: reportId,
        orderId: 'order-1',
        state: RiskInterventionState.awaitingTriage,
        driverId: 'driver-1',
        decisionDueAt: DateTime(2026, 8, 8, 10),
        instruction: null,
        driverReleasedAt: null,
      );

  @override
  Future<void> acceptReport(String reportId) async => operations.add('accept');

  @override
  Future<void> decideOperation(
    String reportId,
    RiskInterventionState decision, {
    String? instruction,
  }) async {
    operations.add(decision.databaseValue);
    _decisionAttempts++;
    if (failFirstDecision && _decisionAttempts == 1) {
      throw StateError('decision failed');
    }
  }

  @override
  Future<List<RiskReportNote>> fetchNotes(String reportId) async => const [];

  @override
  Future<void> addInternalNote(String reportId, String body) async {}

  @override
  Future<void> confirmCustodyResolved(String reportId, {String? note}) async {}

  @override
  Future<void> holdBeforePickup(String reportId, {String? instruction}) async {}

  @override
  Future<void> resumeHeldOrder(String reportId) async {}

  @override
  Future<void> assignToMe(String reportId) async => acceptReport(reportId);

  @override
  Future<List<RiskMessageEvidence>> attachMessageEvidence(
    String reportId,
    List<String> messageIds,
  ) async => const [];

  @override
  Future<void> changeStatus(
    String reportId,
    RiskStatus status, {
    String? resolution,
  }) async => operations.add('status:${status.databaseValue}');

  @override
  Future<void> createReport(RiskReportDraft draft) async {}

  @override
  Future<List<RiskReportEvent>> fetchEvents(String reportId) async => const [];

  @override
  Future<List<RiskMessageEvidence>> fetchMessageEvidence(
    String reportId,
  ) async => const [];

  @override
  Future<List<RiskOrderMessage>> fetchOrderMessages(String orderId) async =>
      const [];

  @override
  Future<List<RiskReport>> fetchReports() async => const [];
}
