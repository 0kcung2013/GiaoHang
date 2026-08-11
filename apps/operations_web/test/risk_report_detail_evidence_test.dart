import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/risk_reports/data/risk_report_repository.dart';
import 'package:operations_web/features/risk_reports/dialogs/risk_report_detail_dialog.dart';
import 'package:operations_web/features/risk_reports/models/risk_message_evidence.dart';
import 'package:operations_web/features/risk_reports/models/risk_report.dart';

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
    expect(find.text('10.77650, 106.70090'), findsOneWidget);
    expect(find.text('Mở bản đồ'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(repository.requestedOrderId, 'order-1');
    expect(repository.requestedReportId, 'risk-1');
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
