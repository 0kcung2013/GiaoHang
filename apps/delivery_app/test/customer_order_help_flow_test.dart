import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/order_help/data/customer_support_ticket_repository.dart';
import 'package:delivery_app/features/order_help/widgets/customer_order_help_flow.dart';
import 'package:delivery_app/features/risk_reports/data/participant_risk_report_query_repository.dart';
import 'package:delivery_app/features/risk_reports/data/risk_report_repository.dart';
import 'package:delivery_app/features/risk_reports/models/participant_risk_report_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  testWidgets('routes a delivery delay to customer support', (tester) async {
    final support = _FakeSupportRepository();
    final riskQuery = _FakeRiskQueryRepository();
    final riskCommand = _FakeRiskCommandRepository();
    await _pump(
      tester,
      support: support,
      riskQuery: riskQuery,
      riskCommand: riskCommand,
    );

    await tester.tap(find.text('Mở trợ giúp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giao hàng chậm'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('customer-support-message')),
      'Đơn hàng đã đứng yên hơn ba mươi phút.',
    );
    await tester.tap(find.byKey(const Key('submit-customer-support-ticket')));
    await tester.pumpAndSettle();

    expect(support.created, hasLength(1));
    expect(support.created.single.subject, 'Giao hàng chậm');
    expect(riskCommand.submitCalls, 0);
    expect(find.text('Đã gửi thành công'), findsOneWidget);
  });

  testWidgets('routes a safety issue to the risk wizard', (tester) async {
    final support = _FakeSupportRepository();
    final riskQuery = _FakeRiskQueryRepository();
    final riskCommand = _FakeRiskCommandRepository();
    await _pump(
      tester,
      support: support,
      riskQuery: riskQuery,
      riskCommand: riskCommand,
    );

    await tester.tap(find.text('Mở trợ giúp'));
    await tester.pumpAndSettle();
    final safetyOption = find.text('An toàn hoặc đáng ngờ');
    await tester.scrollUntilVisible(
      safetyOption,
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(safetyOption);
    await tester.pumpAndSettle();
    expect(find.text('Thêm thông tin'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      'Khu vực giao hàng đang có dấu hiệu không an toàn.',
    );
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi cho CSKH'));
    await tester.pumpAndSettle();

    expect(support.created, isEmpty);
    expect(riskCommand.submitCalls, 1);
    expect(find.text('Đã gửi thành công'), findsOneWidget);
  });

  testWidgets('opens an existing active risk instead of creating a duplicate', (
    tester,
  ) async {
    final existing = ParticipantRiskReportSummary(
      id: 'existing-report',
      orderId: 'order-1',
      category: RiskCategory.safety,
      status: RiskStatus.investigating,
      title: 'Vấn đề an toàn',
      description: 'Đang được kiểm tra.',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final support = _FakeSupportRepository();
    final riskQuery = _FakeRiskQueryRepository(existing: existing);
    final riskCommand = _FakeRiskCommandRepository();
    await _pump(
      tester,
      support: support,
      riskQuery: riskQuery,
      riskCommand: riskCommand,
    );

    await tester.tap(find.text('Mở trợ giúp'));
    await tester.pumpAndSettle();
    final safetyOption = find.text('An toàn hoặc đáng ngờ');
    await tester.scrollUntilVisible(
      safetyOption,
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(safetyOption);
    await tester.pumpAndSettle();

    expect(find.text('Yêu cầu đang được xử lý'), findsOneWidget);
    expect(riskCommand.submitCalls, 0);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeSupportRepository support,
  required _FakeRiskQueryRepository riskQuery,
  required _FakeRiskCommandRepository riskCommand,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showCustomerOrderHelpFlow(
              context,
              order: _order,
              supportRepository: support,
              riskQueryRepository: riskQuery,
              riskCommandRepository: riskCommand,
            ),
            child: const Text('Mở trợ giúp'),
          ),
        ),
      ),
    ),
  );
}

class _FakeSupportRepository implements ParticipantSupportTicketRepository {
  final created = <SupportTicketDraft>[];

  @override
  Future<SupportTicket> create(SupportTicketDraft draft) async {
    created.add(draft);
    return SupportTicket(
      id: 'ticket-123',
      requesterId: draft.requesterId,
      requesterRole: 'customer',
      orderId: draft.orderId,
      subject: draft.subject,
      message: draft.message,
      status: SupportTicketStatus.open,
      priority: draft.priority,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  @override
  Future<List<SupportTicket>> fetchForOrder(String orderId) async => const [];

  @override
  Stream<List<SupportTicket>> watchForOrder(String orderId) =>
      const Stream.empty();
}

class _FakeRiskQueryRepository implements ParticipantRiskReportQueryRepository {
  _FakeRiskQueryRepository({this.existing});

  final ParticipantRiskReportSummary? existing;

  @override
  Future<ParticipantRiskReportSummary?> findActive(
    String orderId,
    RiskCategory category,
  ) async => existing;

  @override
  Future<List<ParticipantRiskReportSummary>> fetchForOrder(
    String orderId,
  ) async => existing == null ? const [] : [existing!];

  @override
  Future<List<RiskReportEvent>> fetchEvents(String reportId) async => const [];

  @override
  Stream<List<ParticipantRiskReportSummary>> watchForOrder(String orderId) =>
      const Stream.empty();
}

class _FakeRiskCommandRepository implements ParticipantRiskReportRepository {
  int submitCalls = 0;

  @override
  Future<RiskReportSubmissionResult> submit(
    ParticipantRiskReportDraft draft, {
    RiskReportProgressCallback? onProgress,
  }) async {
    submitCalls += 1;
    return const RiskReportSubmissionResult(
      reportId: 'risk-123',
      status: RiskStatus.open,
    );
  }
}

final _order = OrderModel(
  id: 'order-1',
  customerId: 'customer-1',
  driverId: 'driver-1',
  status: 'delivering',
  pickupAddress: 'Điểm lấy hàng',
  pickupLat: 10.7,
  pickupLng: 106.6,
  deliveryAddress: 'Điểm giao hàng',
  deliveryLat: 10.8,
  deliveryLng: 106.7,
  createdAt: DateTime(2026),
  trackingCode: 'GH123',
  deliveryFee: 30000,
  serviceType: 'standard',
  paymentMethod: 'cash',
  updatedAt: DateTime(2026),
);
