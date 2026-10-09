import 'dart:async';

import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/driver/screens/navigation/data/driver_delivery_arrival_repository.dart';
import 'package:delivery_app/features/driver/screens/navigation/models/driver_recipient_wait.dart';
import 'package:delivery_app/features/driver/screens/navigation/utils/driver_recipient_wait_strings.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_recipient_wait_card.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_recipient_wait_region.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_redelivery_fee_dialog.dart';
import 'package:delivery_app/features/risk_reports/data/participant_risk_report_query_repository.dart';
import 'package:delivery_app/features/risk_reports/data/risk_intervention_repository.dart';
import 'package:delivery_app/features/risk_reports/models/participant_risk_report_summary.dart';
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
}) => ParticipantRiskReportSummary.fromJson({
  'id': 'report',
  'order_id': 'order',
  'reported_by': reporter,
  'reporter_role_snapshot': role,
  'category': category,
  'status': status,
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
  test(
    '15 minutes begins at report creation, independently of CSKH deadline',
    () {
      final wait = DriverRecipientWait(_report());
      expect(wait.remainingAt(_created), const Duration(minutes: 15));
      expect(
        wait.remainingAt(_created.add(const Duration(minutes: 10))),
        const Duration(minutes: 5),
      );
      expect(
        wait.remainingAt(_created.add(const Duration(minutes: 15))),
        Duration.zero,
      );
      expect(
        wait.remainingAt(_created.add(const Duration(hours: 2))),
        Duration.zero,
      );
      expect(
        wait.remainingAt(_created.subtract(const Duration(hours: 2))),
        DriverRecipientWait.window,
      );
      expect(DriverRecipientWait.redeliveryPerKm, 5000);
    },
  );

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

  testWidgets('reopening restores remaining time and opens fee terms', (
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
            child: const Scaffold(body: Text('Bản đồ')),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await mount();
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text(DriverRecipientWaitStrings.waiting), findsOneWidget);
    await tester.tap(find.text(DriverRecipientWaitStrings.recall));
    await tester.pumpAndSettle();
    expect(find.byType(DriverRedeliveryFeeDialog), findsOneWidget);
    expect(find.text(DriverRecipientWaitStrings.origin), findsOneWidget);
    expect(find.text(DriverRecipientWaitStrings.payer), findsNWidgets(2));
    expect(find.text(DriverRecipientWaitStrings.rate), findsOneWidget);
    await tester.tap(find.text(DriverRecipientWaitStrings.close));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await mount();
    expect(find.text('10:00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'expiry on resume reopens request, sends once and restores sent state',
    (tester) async {
      var serverNow = _created.add(const Duration(minutes: 14));
      final reports = _Reports();
      final interventions = _Interventions();
      addTearDown(reports.close);
      addTearDown(interventions.close);
      final arrival = _arrival(() => serverNow);
      Future<void> mount() async {
        await tester.pumpWidget(
          MaterialApp(
            home: DriverRecipientWaitRegion(
              order: _order,
              reports: reports,
              interventions: interventions,
              arrivalRepository: arrival,
              child: const Scaffold(body: Text('Bản đồ')),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await mount();
      await tester.tap(find.text(DriverRecipientWaitStrings.minimize));
      await tester.pumpAndSettle();
      expect(find.byType(DriverRecipientWaitCard), findsNothing);
      serverNow = _created.add(const Duration(minutes: 16));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text(DriverRecipientWaitStrings.expired), findsOneWidget);
      expect(reports.posts, 0);
      await tester.tap(find.text(DriverRecipientWaitStrings.sendReturn));
      await tester.pumpAndSettle();
      expect(reports.posts, 1);
      expect(find.text(DriverRecipientWaitStrings.returnSent), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await mount();
      expect(find.text(DriverRecipientWaitStrings.returnSent), findsOneWidget);
      expect(find.text(DriverRecipientWaitStrings.sendReturn), findsNothing);
      expect(reports.posts, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'CSKH decision removes form; offline clock disables return request',
    (tester) async {
      var offline = true;
      final reports = _Reports();
      final interventions = _Interventions();
      addTearDown(reports.close);
      addTearDown(interventions.close);
      final arrival = DriverDeliveryArrivalRepository(
        invoke: (_, _) async {
          if (offline) throw StateError('network');
          return _snapshot(_created.add(const Duration(minutes: 16)));
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DriverRecipientWaitRegion(
            order: _order,
            reports: reports,
            interventions: interventions,
            arrivalRepository: arrival,
            child: const Scaffold(body: Text('Bản đồ')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(DriverRecipientWaitStrings.clockError), findsOneWidget);
      expect(find.text(DriverRecipientWaitStrings.sendReturn), findsNothing);
      offline = false;
      await tester.tap(find.text(DriverRecipientWaitStrings.retry));
      await tester.pumpAndSettle();
      expect(find.text(DriverRecipientWaitStrings.sendReturn), findsOneWidget);
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
    final reports = _Reports();
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
          child: const Scaffold(body: Text('Bản đồ')),
        ),
      ),
    );
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
    'failed return request stays retryable and never claims success',
    (tester) async {
      final reports = _Reports()..failPost = true;
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
            child: const Scaffold(body: Text('Bản đồ')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(DriverRecipientWaitStrings.sendReturn));
      await tester.pumpAndSettle();
      expect(find.text(DriverRecipientWaitStrings.sendError), findsOneWidget);
      expect(find.text(DriverRecipientWaitStrings.returnSent), findsNothing);
      reports.failPost = false;
      await tester.tap(find.text(DriverRecipientWaitStrings.sendReturn));
      await tester.pumpAndSettle();
      expect(reports.messages, hasLength(1));
      expect(find.text(DriverRecipientWaitStrings.returnSent), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    for (final scale in [1.0, 1.6]) {
      for (final expired in [false, true]) {
        testWidgets(
          'wait card ${size.width} scale $scale expired $expired fits and scrolls',
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
                          pickupAddress: _order.pickupAddress,
                          remaining: expired
                              ? Duration.zero
                              : const Duration(minutes: 15),
                          onRecall: () {},
                          onRequestReturn: () {},
                          onOpenReport: () {},
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
  ) async => values;
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
