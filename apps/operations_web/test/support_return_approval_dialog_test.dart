import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:operations_web/features/returns/dialogs/support_return_approval_dialog.dart';
import 'package:operations_web/features/returns/constants/return_approval_strings.dart';
import 'package:operations_web/features/returns/services/return_route_quote_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('CSKH chỉ có thể hoàn đơn về đúng nơi lấy hàng', (tester) async {
    ReturnApprovalDraft? submitted;
    final quoteService = ReturnRouteQuoteService(
      SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
      incidentOriginLoader: (_) async => (10.82, 106.72),
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'routes': [
              {'distance': 1800, 'duration': 420},
            ],
          }),
          200,
        ),
      ),
    );
    final report = RiskReport(
      id: 'risk-1',
      orderId: 'order-1',
      reportedBy: 'driver-1',
      assignedTo: 'support-1',
      category: RiskCategory.safety,
      severity: RiskSeverity.medium,
      status: RiskStatus.investigating,
      title: 'Không thể bàn giao',
      description: 'Người nhận không có mặt tại điểm giao.',
      resolution: null,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      order: const RiskOrderSummary(
        trackingCode: 'GH001',
        status: 'delivering',
        pickupAddress: '123 Đường Điểm Lấy',
        pickupLat: 10.81,
        pickupLng: 106.71,
        deliveryAddress: '456 Đường Điểm Giao',
        deliveryLat: 10.82,
        deliveryLng: 106.72,
        deliveryFee: 40000,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              submitted = await showSupportReturnApprovalDialog(
                context: context,
                report: report,
                quoteService: quoteService,
              );
            },
            child: const Text('Mở duyệt hoàn'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở duyệt hoàn'));
    await tester.pumpAndSettle();

    expect(find.text('Hoàn về nơi lấy hàng'), findsOneWidget);
    expect(find.text('123 Đường Điểm Lấy'), findsOneWidget);
    expect(find.text('Điểm xử lý'), findsNothing);
    expect(find.text('Mã lý do'), findsNothing);
    expect(find.text('delivery_incident'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Phí hoàn'), findsOneWidget);
    expect(find.text('20.000 đ'), findsOneWidget);
    expect(find.text('Cước giao gốc'), findsNothing);
    await tester.tap(find.text('Chi tiết phí'));
    await tester.pumpAndSettle();
    expect(find.text('Cước giao gốc'), findsOneWidget);
    expect(find.text('40.000 đ'), findsOneWidget);
    expect(find.text('Tổng tài xế nhận'), findsOneWidget);
    expect(find.text('60.000 đ'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('approve-order-return')));
    await tester.tap(find.byKey(const Key('approve-order-return')));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.destinationType, ReturnDestinationType.sender);
    expect(submitted!.destinationAddress, '123 Đường Điểm Lấy');
    expect(submitted!.destinationLat, 10.81);
    expect(submitted!.destinationLng, 106.71);
    expect(submitted!.driverReturnEarning, 20000);
    expect(submitted!.reasonCode, 'delivery_incident');
    expect(submitted!.feePayer, ReturnFeePayer.platform);
    expect(submitted!.customerReturnCharge, 0);
    expect(submitted!.routeOriginLat, 10.82);
    expect(submitted!.routeOriginLng, 106.72);
    expect(submitted!.instruction, isNull);
  });

  testWidgets('recalculating blocks approval until the new quote arrives', (
    tester,
  ) async {
    final nextQuote = Completer<ReturnRouteQuote>();
    var calls = 0;
    ReturnApprovalDraft? submitted;
    await _openDialog(
      tester,
      service: _QuoteService(
        () => ++calls == 1 ? Future.value(_quote) : nextQuote.future,
      ),
      onSubmit: (draft) => submitted = draft,
    );
    final approve = find.byKey(const Key('approve-order-return'));
    expect(tester.widget<FilledButton>(approve).onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('recalculate-return-route')));
    await tester.pump();
    expect(find.text(ReturnApprovalStrings.calculatingRoute), findsOneWidget);
    expect(tester.widget<FilledButton>(approve).onPressed, isNull);
    await tester.tap(approve);
    expect(submitted, isNull);
    nextQuote.complete(
      const ReturnRouteQuote(
        originLat: 10.83,
        originLng: 106.73,
        distanceMeters: 2400,
        durationSeconds: 600,
        source: ReturnQuoteSource.osrm,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(approve);
    await tester.pumpAndSettle();
    expect(submitted!.routeOriginLat, 10.83);
    expect(submitted!.routeDistanceMeters, 2400);
  });

  testWidgets('route error can be retried without showing technical details', (
    tester,
  ) async {
    var calls = 0;
    await _openDialog(
      tester,
      service: _QuoteService(() async {
        if (++calls == 1) throw StateError('technical-private-detail');
        return _quote;
      }),
    );
    expect(find.text(ReturnApprovalStrings.routeError), findsOneWidget);
    expect(find.textContaining('technical-private-detail'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('approve-order-return')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('recalculate-return-route')));
    await tester.pumpAndSettle();
    expect(find.text(ReturnApprovalStrings.routeError), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('approve-order-return')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('missing pickup prevents quoting and approval', (tester) async {
    var calls = 0;
    await _openDialog(
      tester,
      report: _testReport(hasPickup: false),
      service: _QuoteService(() async {
        calls++;
        return _quote;
      }),
    );
    expect(find.text(ReturnApprovalStrings.missingPickup), findsOneWidget);
    expect(calls, 0);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('approve-order-return')))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'optional instruction survives collapse and is submitted trimmed',
    (tester) async {
      ReturnApprovalDraft? submitted;
      await _openDialog(tester, onSubmit: (draft) => submitted = draft);
      final toggle = find.text(ReturnApprovalStrings.optionalInstruction);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('return-driver-instruction'));
      await tester.ensureVisible(field);
      await tester.enterText(field, '  Gọi chủ kho trước khi trả hàng.  ');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).controller!.text,
        '  Gọi chủ kho trước khi trả hàng.  ',
      );
      await tester.tap(find.byKey(const Key('approve-order-return')));
      await tester.pumpAndSettle();
      expect(submitted!.instruction, 'Gọi chủ kho trước khi trả hàng.');
    },
  );

  for (final viewport in [
    (size: const Size(320, 568), scale: 1.0),
    (size: const Size(390, 568), scale: 1.6),
    (size: const Size(1280, 850), scale: 1.0),
    (size: const Size(740, 360), scale: 1.0),
  ]) {
    testWidgets(
      'approval remains usable at ${viewport.size} scale ${viewport.scale}',
      (tester) async {
        tester.view.physicalSize = viewport.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ReturnApprovalDraft? submitted;
        await _openDialog(
          tester,
          scale: viewport.scale,
          onSubmit: (draft) => submitted = draft,
        );
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('approve-order-return')).hitTestable(),
          findsOneWidget,
        );
        await tester.ensureVisible(
          find.byKey(const Key('return-optional-instruction')),
        );
        await tester.tap(find.byKey(const Key('return-optional-instruction')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('return-driver-instruction')),
        );
        await tester.enterText(
          find.byKey(const Key('return-driver-instruction')),
          'Liên hệ chủ kho.',
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text(ReturnApprovalStrings.cancel));
        await tester.tap(find.text(ReturnApprovalStrings.cancel));
        await tester.pumpAndSettle();
        expect(find.text(ReturnApprovalStrings.title), findsNothing);
        expect(submitted, isNull);
      },
    );
  }

  testWidgets('keyboard keeps the instruction and approval usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await _openDialog(tester);
    await tester.ensureVisible(
      find.byKey(const Key('return-optional-instruction')),
    );
    await tester.tap(find.byKey(const Key('return-optional-instruction')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('return-driver-instruction')),
    );
    await tester.enterText(
      find.byKey(const Key('return-driver-instruction')),
      'Gọi chủ kho.',
    );
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('approve-order-return')).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets(
    'landscape keyboard preserves the open instruction and allows cancellation',
    (tester) async {
      tester.view.physicalSize = const Size(740, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await _openDialog(tester);
      await tester.ensureVisible(
        find.text(ReturnApprovalStrings.optionalInstruction),
      );
      await tester.tap(find.text(ReturnApprovalStrings.optionalInstruction));
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('return-driver-instruction'));
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Gọi chủ kho trước khi trả.');
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      await tester.pumpAndSettle();
      await tester.ensureVisible(field);
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Gọi chủ kho trước khi trả.',
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text(ReturnApprovalStrings.cancel));
      await tester.tap(find.text(ReturnApprovalStrings.cancel));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

const _quote = ReturnRouteQuote(
  originLat: 10.82,
  originLng: 106.72,
  distanceMeters: 1800,
  durationSeconds: 420,
  source: ReturnQuoteSource.osrm,
);

class _QuoteService implements ReturnRouteQuoteService {
  _QuoteService(this.load);
  final Future<ReturnRouteQuote> Function() load;
  @override
  Future<ReturnRouteQuote> quote({
    required String riskReportId,
    required RiskOrderSummary order,
    required double destinationLat,
    required double destinationLng,
  }) => load();
}

Future<void> _openDialog(
  WidgetTester tester, {
  RiskReport? report,
  ReturnRouteQuoteService? service,
  double scale = 1,
  void Function(ReturnApprovalDraft?)? onSubmit,
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
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final draft = await showSupportReturnApprovalDialog(
                context: context,
                report: report ?? _testReport(),
                quoteService: service ?? _QuoteService(() async => _quote),
              );
              onSubmit?.call(draft);
            },
            child: const Text('Mở duyệt hoàn'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở duyệt hoàn'));
  await tester.pumpAndSettle();
}

RiskReport _testReport({bool hasPickup = true}) => RiskReport(
  id: 'risk-1',
  orderId: 'order-1',
  reportedBy: 'driver-1',
  assignedTo: 'support-1',
  category: RiskCategory.contactIssue,
  severity: RiskSeverity.medium,
  status: RiskStatus.investigating,
  title: 'Khách không nghe máy',
  description: 'Đã chờ 10 phút, khách không nghe máy.',
  resolution: null,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  order: RiskOrderSummary(
    trackingCode: 'GH-10195',
    status: 'delivering',
    pickupAddress: '123 Đường Điểm Lấy',
    pickupLat: hasPickup ? 10.81 : null,
    pickupLng: hasPickup ? 106.71 : null,
    deliveryAddress: '456 Đường Điểm Giao',
    deliveryLat: 10.82,
    deliveryLng: 106.72,
    deliveryFee: 40000,
  ),
);
