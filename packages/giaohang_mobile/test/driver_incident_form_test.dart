import 'dart:async';

import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/features/risk_reports/data/participant_risk_report_query_repository.dart';
import 'package:giaohang_mobile/features/risk_reports/data/risk_report_repository.dart';
import 'package:giaohang_mobile/features/risk_reports/models/participant_risk_report_summary.dart';
import 'package:giaohang_mobile/features/risk_reports/utils/risk_report_strings.dart';
import 'package:giaohang_mobile/features/risk_reports/widgets/driver_pending_incident_region.dart';
import 'package:giaohang_mobile/features/risk_reports/widgets/risk_report_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('single form fits $size with text $scale and keyboard', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = _SubmitRepository();
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
                viewInsets: const EdgeInsets.only(bottom: 180),
              ),
              child: Scaffold(
                body: RiskReportSheet(
                  order: _order(),
                  role: RiskReporterRole.driver,
                  repository: repo,
                  initialLatitude: 10.78,
                  initialLongitude: 106.68,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.text(RiskReportStrings.driverIncidentTitle),
          findsOneWidget,
        );
        expect(find.text(RiskReportStrings.cargoMismatch), findsOneWidget);
        expect(find.text(RiskReportStrings.pickupUnavailable), findsOneWidget);
        expect(find.text(RiskReportStrings.otherIncident), findsOneWidget);
        expect(find.text('Tiếp tục'), findsNothing);
        expect(find.text('Quay lại'), findsNothing);
        await tester.ensureVisible(find.text(RiskReportStrings.cargoMismatch));
        await tester.pumpAndSettle();
        await tester.tap(find.text(RiskReportStrings.cargoMismatch));
        await tester.pump();
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(
          find.byType(TextField),
          'Kiện hàng lớn hơn kích thước khai báo.',
        );
        await tester.ensureVisible(find.text(RiskReportStrings.sendIncident));
        await tester.tap(find.text(RiskReportStrings.sendIncident));
        await tester.pump();
        expect(find.text(RiskReportStrings.cargoPhotoRequired), findsOneWidget);
        expect(repo.calls, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  testWidgets('actual pickup hides cargo even while status is picking_up', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiskReportSheet(
            order: _order(picked: true),
            role: RiskReporterRole.driver,
            repository: _SubmitRepository(),
            initialCategory: RiskCategory.cargoIssue,
            initialLatitude: 10.78,
            initialLongitude: 106.68,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(RiskReportStrings.cargoMismatch), findsNothing);
    expect(find.text(RiskReportStrings.pickupUnavailable), findsNothing);
    expect(find.text(RiskReportStrings.deliveryUnavailable), findsOneWidget);
    expect(find.text(RiskReportStrings.cargoRequestHint), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'pending cargo report blocks pickup until closed; other reports do not',
    (tester) async {
      final repo = _QueryRepository();
      addTearDown(repo.stream.close);
      bool? blocked;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverPendingIncidentRegion(
              order: _order(),
              repository: repo,
              builder: (_, value) {
                blocked = value;
                return const Text('Pickup controls');
              },
            ),
          ),
        ),
      );
      repo.stream.add([_report(RiskCategory.other, RiskStatus.open)]);
      await tester.pumpAndSettle();
      expect(blocked, isFalse);
      repo.stream.add([_report(RiskCategory.cargoIssue, RiskStatus.open)]);
      await tester.pumpAndSettle();
      expect(blocked, isTrue);
      expect(find.byKey(const Key('driver-incident-pending')), findsOneWidget);
      expect(find.text(RiskReportStrings.viewConversation), findsOneWidget);
      repo.stream.add([_report(RiskCategory.cargoIssue, RiskStatus.resolved)]);
      await tester.pumpAndSettle();
      expect(blocked, isFalse);
      expect(find.byKey(const Key('driver-incident-pending')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('another driver cargo report does not block current assignment', (
    tester,
  ) async {
    final repo = _QueryRepository();
    addTearDown(repo.stream.close);
    bool? blocked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverPendingIncidentRegion(
            order: _order(),
            repository: repo,
            builder: (_, value) {
              blocked = value;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    repo.stream.add([
      _report(RiskCategory.cargoIssue, RiskStatus.open, driver: 'old-driver'),
    ]);
    await tester.pump();
    expect(blocked, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

OrderModel _order({bool picked = false}) => OrderModel.fromJson({
  'id': 'order-1',
  'customer_id': 'customer-1',
  'driver_id': 'driver-1',
  'status': 'picking_up',
  'tracking_code': 'GH-TEST',
  'pickup_lat': 10.78,
  'pickup_lng': 106.68,
  'delivery_lat': 10.8,
  'delivery_lng': 106.71,
  if (picked) 'actual_picked_up_at': '2026-10-11T00:00:00Z',
});

ParticipantRiskReportSummary _report(
  RiskCategory category,
  RiskStatus status, {
  String driver = 'driver-1',
}) => ParticipantRiskReportSummary(
  id: 'report-1',
  orderId: 'order-1',
  category: category,
  status: status,
  title: 'Sự cố',
  description: 'Hàng không đúng thông tin',
  reportedBy: driver,
  reporterRole: RiskReporterRole.driver,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _SubmitRepository implements ParticipantRiskReportRepository {
  int calls = 0;
  @override
  Future<RiskReportSubmissionResult> submit(
    ParticipantRiskReportDraft draft, {
    RiskReportProgressCallback? onProgress,
  }) async {
    calls++;
    return const RiskReportSubmissionResult(
      reportId: 'report-1',
      status: RiskStatus.open,
    );
  }
}

class _QueryRepository implements ParticipantRiskReportQueryRepository {
  final stream =
      StreamController<List<ParticipantRiskReportSummary>>.broadcast();
  @override
  Stream<List<ParticipantRiskReportSummary>> watchForOrder(String orderId) =>
      stream.stream;
  @override
  Future<List<ParticipantRiskReportSummary>> fetchForOrder(
    String orderId,
  ) async => const [];
  @override
  Future<ParticipantRiskReportSummary?> findActive(
    String orderId,
    RiskCategory category,
  ) async => null;
  @override
  Future<List<RiskReportEvent>> fetchEvents(String reportId) async => const [];
}
