import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/risk_reports/data/risk_report_repository.dart';
import 'package:operations_web/features/risk_reports/models/risk_message_evidence.dart';
import 'package:operations_web/features/risk_reports/models/risk_report.dart';
import 'package:operations_web/features/risk_reports/screens/risk_reports_view.dart';

void main() {
  testWidgets('shows report metrics, filters and risk card', (tester) async {
    final repository = _FakeRiskReportRepository([_sampleReport]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiskReportsView(
            isAdmin: true,
            repository: repository,
            currentUserId: 'staff-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rủi ro hệ thống'), findsOneWidget);
    expect(find.text('Địa chỉ nhận bất thường'), findsOneWidget);
    expect(find.text('GH-00001'), findsOneWidget);
    expect(find.text('Nghiêm trọng'), findsWidgets);
    expect(find.text('Khách hàng'), findsOneWidget);
    expect(find.text('Nguyễn An'), findsOneWidget);
    expect(find.text('Quá hạn phân loại'), findsOneWidget);
    expect(find.byKey(const Key('risk-search-field')), findsOneWidget);
  });

  testWidgets('prioritizes overdue triage reports in the queue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeRiskReportRepository([
      _normalSortReport,
      _overdueSortReport,
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiskReportsView(
            isAdmin: false,
            repository: repository,
            currentUserId: 'staff-2',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final overdueY = tester.getTopLeft(find.text('Overdue report')).dy;
    final normalY = tester.getTopLeft(find.text('Normal report')).dy;
    expect(overdueY, lessThan(normalY));
  });

  testWidgets('search filters the visible reports', (tester) async {
    final repository = _FakeRiskReportRepository([_sampleReport]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiskReportsView(
            isAdmin: false,
            repository: repository,
            currentUserId: 'staff-2',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('risk-search-field')),
      'KHÔNG-TỒN-TẠI',
    );
    await tester.pump();

    expect(find.text('Không có báo cáo phù hợp'), findsOneWidget);
  });
}

final _sampleReport = RiskReport(
  id: 'risk-1',
  orderId: 'order-1',
  reportedBy: 'staff-2',
  assignedTo: null,
  category: RiskCategory.suspiciousAddress,
  severity: RiskSeverity.critical,
  status: RiskStatus.open,
  title: 'Địa chỉ nhận bất thường',
  description: 'Khách thay đổi địa chỉ nhận nhiều lần trong một giờ.',
  resolution: null,
  createdAt: DateTime(2026, 8, 1, 10),
  updatedAt: DateTime(2026, 8, 1, 10, 5),
  reporterRole: RiskReporterRole.customer,
  reporterName: 'Nguyễn An',
  triageDueAt: DateTime(2026, 8, 1, 10, 10),
  escalatedAt: DateTime(2026, 8, 1, 10, 11),
  order: const RiskOrderSummary(
    trackingCode: 'GH-00001',
    status: 'delivering',
    pickupAddress: 'Thủ Dầu Một, Bình Dương',
    deliveryAddress: 'Quận 1, TP.HCM',
  ),
);

final _normalSortReport = RiskReport(
  id: 'normal-risk',
  orderId: 'normal-order',
  reportedBy: 'customer-1',
  assignedTo: null,
  category: RiskCategory.deliveryDelay,
  severity: RiskSeverity.medium,
  status: RiskStatus.open,
  title: 'Normal report',
  description: 'Waiting for triage.',
  resolution: null,
  createdAt: DateTime(2026, 8, 1, 11),
  updatedAt: DateTime(2026, 8, 1, 11, 5),
  triageDueAt: DateTime(2026, 8, 1, 11, 10),
  order: const RiskOrderSummary(
    trackingCode: 'GH-NORMAL',
    status: 'delivering',
    pickupAddress: 'Pickup',
    deliveryAddress: 'Delivery',
  ),
);

final _overdueSortReport = RiskReport(
  id: 'overdue-risk',
  orderId: 'overdue-order',
  reportedBy: 'driver-1',
  assignedTo: null,
  category: RiskCategory.safety,
  severity: RiskSeverity.high,
  status: RiskStatus.open,
  title: 'Overdue report',
  description: 'Needs immediate triage.',
  resolution: null,
  createdAt: DateTime(2026, 8, 1, 10),
  updatedAt: DateTime(2026, 8, 1, 10, 5),
  triageDueAt: DateTime(2026, 8, 1, 10, 10),
  escalatedAt: DateTime(2026, 8, 1, 10, 11),
  order: const RiskOrderSummary(
    trackingCode: 'GH-OVERDUE',
    status: 'delivering',
    pickupAddress: 'Pickup',
    deliveryAddress: 'Delivery',
  ),
);

class _FakeRiskReportRepository implements RiskReportRepository {
  _FakeRiskReportRepository(this.reports);
  final List<RiskReport> reports;

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
  Future<List<RiskOrderMessage>> fetchOrderMessages(String orderId) async => [];

  @override
  Future<List<RiskMessageEvidence>> fetchMessageEvidence(
    String reportId,
  ) async => [];

  @override
  Future<List<RiskMessageEvidence>> attachMessageEvidence(
    String reportId,
    List<String> messageIds,
  ) async => [];

  @override
  Future<List<RiskReport>> fetchReports() async => reports;
}
