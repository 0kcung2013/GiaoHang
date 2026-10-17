import 'dart:async';
import 'package:giaohang_mobile/features/risk_reports/widgets/driver_risk_instruction_card.dart';

import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/data/driver_delivery_arrival_repository.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/models/driver_recipient_wait.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/utils/driver_recipient_wait_strings.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/widgets/driver_recipient_wait_card.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/widgets/driver_recipient_wait_region.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/widgets/driver_redelivery_fee_dialog.dart';
import 'package:giaohang_mobile/features/risk_reports/data/participant_risk_report_query_repository.dart';
import 'package:giaohang_mobile/features/risk_reports/data/risk_intervention_repository.dart';
import 'package:giaohang_mobile/features/risk_reports/models/participant_risk_report_summary.dart';
import 'package:giaohang_mobile/features/risk_reports/utils/risk_recipient_return_request.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/utils/driver_delivery_arrival_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

final _created = DateTime.utc(2026, 10, 5, 10);
final _order = OrderModel(
  id: 'order',
  customerId: 'customer',
  driverId: 'driver',
  status: 'delivering',
  trackingCode: 'GH-10179',
  deliveryFee: 20000,
  serviceType: 'standard',
  paymentMethod: 'cash',
  pickupAddress: 'Điểm lấy hàng ban đầu',
  pickupLat: 10,
  pickupLng: 106,
  deliveryAddress: 'Điểm giao hàng ban đầu',
  deliveryLat: 10.01,
  deliveryLng: 106.01,
  createdAt: _created,
  updatedAt: _created,
);

ParticipantRiskReportSummary _report({
  String reporter = 'driver',
  String role = 'driver',
  String category = 'contact_issue',
  String status = 'open',
  String? description,
}) => ParticipantRiskReportSummary.fromJson({
  'id': 'report',
  'order_id': 'order',
  'reported_by': reporter,
  'reporter_role_snapshot': role,
  'category': category,
  'status': status,
  'description':
      description ??
      RiskRecipientReturnRequest.describe(
        'Khách không nghe máy sau ba lần gọi.',
      ),
  'created_at': _created.toIso8601String(),
  'updated_at': _created.toIso8601String(),
});

RiskIntervention _intervention(RiskInterventionState state) => RiskIntervention(
  riskReportId: 'report',
  orderId: 'order',
  driverId: 'driver',
  state: state,
  decisionDueAt: _created.add(const Duration(minutes: 10)),
  instruction: null,
  driverReleasedAt: null,
);

void main() {
  for (final entry in ['new-report', 'redelivery', 'legacy-request']) {
    testWidgets('$entry opens conversation for the waiting risk report', (
      tester,
    ) async {
      final reports = _Reports();
      final interventions = _Interventions();
      addTearDown(reports.close);
      addTearDown(interventions.close);
      if (entry == 'legacy-request') {
        reports.values = [_report(description: 'Báo cáo từ phiên bản cũ.')];
        reports.messages.add(
          CaseMessage(
            id: 'request',
            caseId: 'report',
            senderId: 'driver',
            senderRole: 'driver',
            visibility: CaseMessageVisibility.public,
            body: RiskRecipientReturnRequest.legacyMessage,
            createdAt: _created,
          ),
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          home: DriverRecipientWaitRegion(
            order: _order,
            reports: reports,
            interventions: interventions,
            arrivalRepository: _arrival(
              () => _created.add(const Duration(minutes: 1)),
            ),
            child: Scaffold(
              body: DriverRiskInstructionCard(
                intervention: _intervention(
                  RiskInterventionState.awaitingTriage,
                ),
                onConfirmCustody: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DriverRecipientWaitCard), findsNothing);
      await tester.tap(find.text('Xem'));
      await tester.pumpAndSettle();
      if (entry == 'redelivery') {
        await tester.tap(find.text(DriverRecipientWaitStrings.recall));
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find.text(DriverRecipientWaitStrings.contactSupport).last,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('risk-chat-sheet')), findsOneWidget);
      expect(find.text('Nội dung đã gửi'), findsNothing);
      expect(find.text('Tiến độ'), findsNothing);
      expect(find.text('Bổ sung thông tin cho CSKH'), findsNothing);
      await tester.enterText(
        find.byKey(const Key('support-chat-composer')),
        'Khách vừa gọi lại, cần hướng dẫn giao lại.',
      );
      await tester.tap(find.byKey(const Key('send-support-chat-message')));
      await tester.pumpAndSettle();
      expect(reports.messages.last.caseId, 'report');
      expect(reports.messages.last.body, contains('Khách vừa gọi lại'));
      expect(reports.posts, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test('wait selects only own driver contact report awaiting a decision', () {
    DriverRecipientWait? select(
      ParticipantRiskReportSummary report, {
      String status = 'delivering',
      RiskInterventionState state = RiskInterventionState.awaitingTriage,
    }) => DriverRecipientWait.select(
      orderId: 'order',
      driverUserId: 'driver',
      orderStatus: status,
      reports: [report],
      intervention: _intervention(state),
    );
    expect(select(_report()), isNotNull);
    expect(select(_report(reporter: 'another-driver')), isNull);
    expect(select(_report(role: 'customer')), isNull);
    expect(select(_report(category: 'safety')), isNull);
    expect(select(_report(status: 'resolved')), isNull);
    expect(select(_report(status: 'dismissed')), isNull);
    expect(select(_report(), status: 'delivered'), isNull);
    for (final state in RiskInterventionState.values.where(
      (s) => s != RiskInterventionState.awaitingTriage,
    )) {
      expect(
        select(_report(), state: state),
        isNull,
        reason: '$state supersedes wait',
      );
    }
  });

  testWidgets('new report waits for CSKH immediately and opens fee terms', (
    tester,
  ) async {
    final reports = _Reports();
    final interventions = _Interventions();
    addTearDown(reports.close);
    addTearDown(interventions.close);
    final arrival = _arrival(() => _created.add(const Duration(minutes: 5)));
    Future<void> mount() async {
      await tester.pumpWidget(
        MaterialApp(
          home: DriverRecipientWaitRegion(
            order: _order,
            reports: reports,
            interventions: interventions,
            arrivalRepository: arrival,
            child: Scaffold(
              body: DriverRiskInstructionCard(
                intervention: _intervention(
                  RiskInterventionState.awaitingTriage,
                ),
                onConfirmCustody: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DriverRecipientWaitCard), findsNothing);
      await tester.tap(find.text('Xem'));
      await tester.pumpAndSettle();
    }

    await mount();
    expect(find.text('10:00'), findsNothing);
    expect(find.text('15:00'), findsNothing);
    expect(find.text(DriverRecipientWaitStrings.waiting), findsOneWidget);
    await tester.tap(find.text(DriverRecipientWaitStrings.recall));
    await tester.pumpAndSettle();
    expect(find.byType(DriverRedeliveryFeeDialog), findsOneWidget);
    expect(find.text(DriverRecipientWaitStrings.origin), findsOneWidget);
    expect(find.text(DriverRecipientWaitStrings.payer), findsOneWidget);
    expect(find.text(DriverRecipientWaitStrings.rate), findsOneWidget);
    await tester.tap(find.text(DriverRecipientWaitStrings.close));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await mount();
    expect(find.text(DriverRecipientWaitStrings.waiting), findsOneWidget);
    expect(find.text(DriverRecipientWaitStrings.sendReturn), findsNothing);
    expect(reports.posts, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'reopen and resume preserve combined request without posting again',
    (tester) async {
      final reports = _Reports();
      final interventions = _Interventions();
      addTearDown(reports.close);
      addTearDown(interventions.close);
      var arrivalReads = 0;
      final arrival = DriverDeliveryArrivalRepository(
        invoke: (_, _) async {
          arrivalReads++;
          throw StateError('Combined reports do not need another arrival read');
        },
      );
      Future<void> mount() async {
        await tester.pumpWidget(
          MaterialApp(
            home: DriverRecipientWaitRegion(
              order: _order,
              reports: reports,
              interventions: interventions,
              arrivalRepository: arrival,
              child: Scaffold(
                body: DriverRiskInstructionCard(
                  intervention: _intervention(
                    RiskInterventionState.awaitingTriage,
                  ),
                  onConfirmCustody: () async {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DriverRecipientWaitCard), findsNothing);
        await tester.tap(find.text('Xem'));
        await tester.pumpAndSettle();
      }

      await mount();
      await tester.tap(find.text(DriverRecipientWaitStrings.minimize));
      await tester.pumpAndSettle();
      expect(find.byType(DriverRecipientWaitCard), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(DriverRecipientWaitCard), findsNothing);
      await tester.tap(find.text('Xem'));
      await tester.pumpAndSettle();
      expect(find.byType(DriverRecipientWaitCard), findsOneWidget);
      expect(reports.posts, 0);
      expect(find.text(DriverRecipientWaitStrings.sendReturn), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await mount();
      expect(find.text(DriverRecipientWaitStrings.waiting), findsOneWidget);
      expect(find.text(DriverRecipientWaitStrings.sendReturn), findsNothing);
      expect(reports.posts, 0);
      expect(arrivalReads, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'offline refresh retries and CSKH decision removes approval form',
    (tester) async {
      final reports = _Reports()..failFetch = true;
      final interventions = _Interventions();
      addTearDown(reports.close);
      addTearDown(interventions.close);
      await tester.pumpWidget(
        MaterialApp(
          home: DriverRecipientWaitRegion(
            order: _order,
            reports: reports,
            interventions: interventions,
            child: Scaffold(
              body: DriverRiskInstructionCard(
                intervention: _intervention(
                  RiskInterventionState.awaitingTriage,
                ),
                onConfirmCustody: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DriverRecipientWaitCard), findsNothing);
      await tester.tap(find.text('Xem'));
      await tester.pumpAndSettle();
      expect(find.text(DriverRecipientWaitStrings.syncError), findsOneWidget);
      expect(find.text(DriverRecipientWaitStrings.sendReturn), findsNothing);
      reports.failFetch = false;
      await tester.tap(find.text(DriverRecipientWaitStrings.retry));
      await tester.pumpAndSettle();
      expect(find.text(DriverRecipientWaitStrings.waiting), findsOneWidget);
      interventions.value = _intervention(RiskInterventionState.returnRequired);
      interventions.controller.add(interventions.value);
      await tester.pumpAndSettle();
      expect(find.byType(DriverRecipientWaitCard), findsNothing);
      expect(reports.posts, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('request checks fresh CSKH decision before posting', (
    tester,
  ) async {
    final reports = _Reports()
      ..values = [_report(description: 'Báo cáo cũ chưa xin hoàn.')];
    final interventions = _Interventions();
    addTearDown(reports.close);
    addTearDown(interventions.close);
    await tester.pumpWidget(
      MaterialApp(
        home: DriverRecipientWaitRegion(
          order: _order,
          reports: reports,
          interventions: interventions,
          arrivalRepository: _arrival(
            () => _created.add(const Duration(minutes: 16)),
          ),
          child: Scaffold(
            body: DriverRiskInstructionCard(
              intervention: _intervention(RiskInterventionState.awaitingTriage),
              onConfirmCustody: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DriverRecipientWaitCard), findsNothing);
    await tester.tap(find.text('Xem'));
    await tester.pumpAndSettle();
    // Quyết định đã đổi trên server, Realtime chưa gửi tới client.
    interventions.value = _intervention(RiskInterventionState.continueDelivery);
    await tester.tap(find.text(DriverRecipientWaitStrings.sendReturn));
    await tester.pumpAndSettle();
    expect(reports.posts, 0);
    expect(find.byType(DriverRecipientWaitCard), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'legacy report requests return at ten minutes without another wait',
    (tester) async {
      final reports = _Reports()
        ..values = [_report(description: 'Báo cáo cũ chưa xin hoàn.')];
      final interventions = _Interventions();
      addTearDown(reports.close);
      addTearDown(interventions.close);
      var allowed = false;
      final arrival = DriverDeliveryArrivalRepository(
        invoke: (_, _) async => {
          ..._snapshot(
            allowed ? _created : _created.subtract(const Duration(seconds: 1)),
          ),
          'can_report_recipient': allowed,
        },
      );
      Future<void> mount() async {
        await tester.pumpWidget(
          MaterialApp(
            home: DriverRecipientWaitRegion(
              order: _order,
              reports: reports,
              interventions: interventions,
              arrivalRepository: arrival,
              child: Scaffold(
                body: DriverRiskInstructionCard(
                  intervention: _intervention(
                    RiskInterventionState.awaitingTriage,
                  ),
                  onConfirmCustody: () async {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DriverRecipientWaitCard), findsNothing);
        await tester.tap(find.text('Xem'));
        await tester.pumpAndSettle();
      }

      await mount();
      expect(find.text(DriverRecipientWaitStrings.sendReturn), findsOneWidget);
      await tester.tap(find.text(DriverRecipientWaitStrings.sendReturn));
      await tester.pumpAndSettle();
      expect(reports.posts, 0);
      expect(
        find.text(DriverDeliveryArrivalStrings.waitRequired),
        findsOneWidget,
      );
      allowed = true;
      await tester.tap(find.text(DriverRecipientWaitStrings.sendReturn));
      await tester.tap(find.text(DriverRecipientWaitStrings.sendReturn));
      await tester.pumpAndSettle();
      expect(reports.posts, 1);
      expect(find.text(DriverRecipientWaitStrings.waiting), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await mount();
      expect(find.text(DriverRecipientWaitStrings.sendReturn), findsNothing);
      expect(find.text(DriverRecipientWaitStrings.waiting), findsOneWidget);
      expect(reports.posts, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed return request stays retryable and never claims success',
    (tester) async {
      final reports = _Reports()
        ..values = [_report(description: 'Báo cáo cũ chưa xin hoàn.')]
        ..failPost = true;
      final interventions = _Interventions();
      addTearDown(reports.close);
      addTearDown(interventions.close);
      await tester.pumpWidget(
        MaterialApp(
          home: DriverRecipientWaitRegion(
            order: _order,
            reports: reports,
            interventions: interventions,
            arrivalRepository: _arrival(
              () => _created.add(const Duration(minutes: 16)),
            ),
            child: Scaffold(
              body: DriverRiskInstructionCard(
                intervention: _intervention(
                  RiskInterventionState.awaitingTriage,
                ),
                onConfirmCustody: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DriverRecipientWaitCard), findsNothing);
      await tester.tap(find.text('Xem'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(DriverRecipientWaitStrings.sendReturn));
      await tester.pumpAndSettle();
      expect(find.text(DriverRecipientWaitStrings.sendError), findsOneWidget);
      expect(find.text(DriverRecipientWaitStrings.waiting), findsNothing);
      reports.failPost = false;
      await tester.tap(find.text(DriverRecipientWaitStrings.sendReturn));
      await tester.pumpAndSettle();
      expect(reports.messages, hasLength(1));
      expect(find.text(DriverRecipientWaitStrings.waiting), findsOneWidget);
      expect(reports.messages.single.body, RiskRecipientReturnRequest.message);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    for (final scale in [1.0, 1.6]) {
      for (final returnRequested in [false, true]) {
        testWidgets(
          'approval card ${size.width} scale $scale requested $returnRequested fits',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    body: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: DriverRecipientWaitCard(
                          orderCode: 'GH-10179',
                          returnRequested: returnRequested,
                          onRecall: () {},
                          onRequestReturn: () {},
                          onContactSupport: () {},
                          onMinimize: () {},
                          onRetry: () {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            expect(tester.takeException(), isNull);
            await tester.ensureVisible(
              find.text(DriverRecipientWaitStrings.minimize),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
      testWidgets('fee dialog ${size.width} scale $scale scrolls to close', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: const Scaffold(
                body: DriverRedeliveryFeeDialog(
                  deliveryAddress: 'Điểm giao hàng ban đầu',
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text(DriverRecipientWaitStrings.close));
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Map<String, Object?> _snapshot(DateTime serverNow) => {
  'delivery_arrived_at': _created
      .subtract(const Duration(minutes: 10))
      .toIso8601String(),
  'server_now': serverNow.toIso8601String(),
  'can_report_recipient': true,
};
DriverDeliveryArrivalRepository _arrival(DateTime Function() now) =>
    DriverDeliveryArrivalRepository(invoke: (_, _) async => _snapshot(now()));

class _Reports
    implements
        ParticipantRiskReportQueryRepository,
        ParticipantRiskConversationRepository {
  final controller =
      StreamController<List<ParticipantRiskReportSummary>>.broadcast();
  List<ParticipantRiskReportSummary> values = [_report()];
  final messages = <CaseMessage>[];
  int posts = 0;
  bool failPost = false;
  bool failFetch = false;
  Future<void> close() => controller.close();
  @override
  Stream<List<ParticipantRiskReportSummary>> watchForOrder(
    String orderId,
  ) async* {
    yield values;
    yield* controller.stream;
  }

  @override
  Future<List<ParticipantRiskReportSummary>> fetchForOrder(
    String orderId,
  ) async {
    if (failFetch) throw StateError('network');
    return values;
  }

  @override
  Future<ParticipantRiskReportSummary?> findActive(
    String orderId,
    RiskCategory category,
  ) async => values.firstOrNull;
  @override
  Future<List<RiskReportEvent>> fetchEvents(String reportId) async => [];
  @override
  Future<List<CaseMessage>> fetchMessages(String reportId) async => messages;
  @override
  Future<void> postMessage(String reportId, String body) async {
    if (failPost) throw StateError('network');
    posts++;
    messages.add(
      CaseMessage(
        id: '$posts',
        caseId: reportId,
        senderId: 'driver',
        senderRole: 'driver',
        visibility: CaseMessageVisibility.public,
        body: body,
        createdAt: _created,
      ),
    );
  }
}

class _Interventions implements RiskInterventionRepository {
  final controller = StreamController<RiskIntervention?>.broadcast();
  RiskIntervention? value = _intervention(RiskInterventionState.awaitingTriage);
  Future<void> close() => controller.close();
  @override
  Stream<RiskIntervention?> watchForOrder(String orderId) async* {
    yield value;
    yield* controller.stream;
  }

  @override
  Future<RiskIntervention?> fetchForOrder(String orderId) async => value;
  @override
  Future<void> confirmCustodyResolved(String reportId, {String? note}) async {}
}
