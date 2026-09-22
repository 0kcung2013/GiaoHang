import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/models/order_status_log_model.dart';
import 'package:delivery_app/core/models/driver_order_cancellation_event.dart';
import 'package:delivery_app/core/providers/customer_providers.dart';
import 'package:delivery_app/core/services/customer_order_command_service.dart';
import 'package:delivery_app/core/services/customer_order_service.dart';
import 'package:delivery_app/core/services/realtime_service.dart';
import 'package:delivery_app/features/customer/screens/order/dialogs/order_detail_sheet.dart';
import 'package:delivery_app/features/customer/screens/order/dialogs/order_detail_strings.dart';
import 'package:delivery_app/features/customer/screens/order/dialogs/widgets/order_cancel_section.dart';
import 'package:delivery_app/features/customer/screens/order/dialogs/widgets/order_detail_activity.dart';
import 'package:delivery_app/features/customer/screens/order/dialogs/widgets/order_detail_header.dart';
import 'package:delivery_app/features/customer/screens/order/widgets/order_card_image.dart';
import 'package:delivery_app/features/order_help/data/customer_support_ticket_repository.dart';
import 'package:delivery_app/features/risk_reports/data/participant_risk_report_query_repository.dart';
import 'package:delivery_app/features/risk_reports/models/participant_risk_report_summary.dart';

void main() {
  test('cancellation errors map to actionable customer messages', () {
    expect(
      OrderDetailStrings.cancellationFailureMessage(
        Exception('ORDER_ALREADY_PICKED_UP'),
      ),
      OrderDetailStrings.cancelInProgressFailure,
    );
    expect(
      OrderDetailStrings.cancellationFailureMessage(
        Exception('CUSTOMER_ID_MISMATCH'),
      ),
      OrderDetailStrings.cancelOwnershipFailure,
    );
    expect(
      OrderDetailStrings.cancellationFailureMessage(Exception('PGRST202')),
      OrderDetailStrings.cancelBackendUnavailableFailure,
    );
    expect(
      OrderDetailStrings.cancellationFailureMessage(Exception('42501')),
      OrderDetailStrings.cancelSessionFailure,
    );
    expect(
      OrderDetailStrings.cancellationFailureMessage(Exception('23505')),
      contains('giao dịch hoàn tiền'),
    );
    expect(
      OrderDetailStrings.cancellationFailureMessage(
        Exception('PostgrestException(code: 40P01, message: deadlock)'),
      ),
      contains('40P01'),
    );
  });

  testWidgets('order detail sheet uses white orange layout and cargo image', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final order = _order();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderItemsProvider.overrideWith((ref, orderId) async => const []),
          orderStatusLogsProvider.overrideWith(
            (ref, orderId) async => const [],
          ),
          orderDeliveryProofsProvider.overrideWith(
            (ref, orderId) async => const [],
          ),
          assignedDriverProvider.overrideWith((ref, orderId) async => null),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => showOrderDetailSheet(
                    context: context,
                    customerId: order.customerId,
                    order: order,
                    supportRepository: const _EmptySupportRepository(),
                    riskRepository: const _EmptyRiskRepository(),
                  ),
                  child: const Text('Mở chi tiết'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở chi tiết'));
    await tester.pumpAndSettle();

    final sheet = tester.widget<Container>(find.byKey(orderDetailSheetKey));
    final sheetDecoration = sheet.decoration as BoxDecoration;
    expect(sheetDecoration.color, AppColors.bgLight);

    final summary = tester.widget<Container>(find.byKey(orderDetailSummaryKey));
    final summaryDecoration = summary.decoration as BoxDecoration;
    expect(summaryDecoration.color, AppColors.bgCard);
    expect(summaryDecoration.color, isNot(AppColors.primary));
    expect(summaryDecoration.color, isNot(AppColors.bgDark));

    expect(find.text('Chi tiết đơn hàng'), findsOneWidget);
    expect(find.text('GH-2026-001'), findsOneWidget);
    expect(find.text('Đang giao'), findsOneWidget);
    expect(find.text('Bánh kem sinh nhật'), findsOneWidget);
    expect(find.text('ĐỒ ĂN'), findsOneWidget);
    expect(find.byKey(orderCardImagePlaceholderKey), findsOneWidget);

    await tester.dragUntilVisible(
      find.text(OrderDetailStrings.routeTitle),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text(OrderDetailStrings.routeTitle), findsOneWidget);

    await tester.dragUntilVisible(
      find.text(OrderDetailStrings.paymentTitle),
      find.byType(ListView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(find.text(OrderDetailStrings.paymentTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timeline repairs cached mojibake log instances', (tester) async {
    const expectedTitle = 'Giao hàng thành công';
    const expectedDescription = 'Đơn hàng đã được giao thành công.';
    const brokenTitle = 'Giao h�ng th�nh c�ng';
    const brokenDescription = 'T�i x� đã giao h�ng th�nh c�ng.';
    final log = OrderStatusLogModel(
      id: 'log-1',
      orderId: 'order-12345678',
      status: 'delivered',
      title: brokenTitle,
      description: brokenDescription,
      createdAt: DateTime(2026, 7, 29, 15, 7),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderStatusLogsProvider.overrideWith((ref, orderId) async => [log]),
        ],
        child: MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.bgLight,
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screenH),
              child: OrderDetailTimelineSection(order: _order()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(expectedTitle), findsOneWidget);
    expect(find.text(expectedDescription), findsOneWidget);
    expect(find.text(brokenTitle), findsNothing);
    expect(find.text(brokenDescription), findsNothing);
  });

  testWidgets(
    'delivering order keeps cancellation visible but disabled with a reason',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final order = _order();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderItemsProvider.overrideWith((ref, orderId) async => const []),
            orderStatusLogsProvider.overrideWith(
              (ref, orderId) async => const [],
            ),
            orderDeliveryProofsProvider.overrideWith(
              (ref, orderId) async => const [],
            ),
            assignedDriverProvider.overrideWith((ref, orderId) async => null),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showOrderDetailSheet(
                    context: context,
                    customerId: order.customerId,
                    order: order,
                    supportRepository: const _EmptySupportRepository(),
                    riskRepository: const _EmptyRiskRepository(),
                  ),
                  child: const Text('Mở chi tiết'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở chi tiết'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.byKey(orderCancelButtonKey),
        find.byType(ListView),
        const Offset(0, -500),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -120));
      await tester.pumpAndSettle();

      expect(find.text(OrderDetailStrings.cancelLockedDescription), findsOne);
      expect(find.text(OrderDetailStrings.cancelLockedAction), findsOne);
      final button = tester.widget<InkWell>(
        find.descendant(
          of: find.byKey(orderCancelButtonKey),
          matching: find.byType(InkWell),
        ),
      );
      expect(button.onTap, isNull);
    },
  );

  testWidgets(
    'confirming cancellation for an assigned order submits the cancellation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var cancellationCalls = 0;
      final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
      client.auth.stopAutoRefresh();
      final service = CustomerOrderService(
        client: client,
        commandService: CustomerOrderCommandService(
          rpcInvoker: (functionName, params) async {
            expect(functionName, 'cancel_customer_order');
            cancellationCalls++;
            if (cancellationCalls == 1) {
              throw Exception('CUSTOMER_ROLE_REQUIRED');
            }
            return [
              {
                'order_id': params['p_order_id'],
                'driver_id': null,
                'tracking_code': '2026-001',
                'new_status': 'cancelled',
              },
            ];
          },
        ),
        realtimeService: _NoopRealtimeService(client),
      );
      final order = _order(status: 'assigned');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerOrderServiceProvider.overrideWithValue(service),
            orderItemsProvider.overrideWith((ref, orderId) async => const []),
            orderStatusLogsProvider.overrideWith(
              (ref, orderId) async => const [],
            ),
            orderDeliveryProofsProvider.overrideWith(
              (ref, orderId) async => const [],
            ),
            assignedDriverProvider.overrideWith((ref, orderId) async => null),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: OrderDetailSheet(
                customerId: order.customerId,
                order: order,
                supportRepository: const _EmptySupportRepository(),
                riskRepository: const _EmptyRiskRepository(),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.dragUntilVisible(
        find.byKey(orderCancelButtonKey),
        find.byType(ListView),
        const Offset(0, -500),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(orderCancelButtonKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Changed plans');
      await tester.tap(find.byKey(orderCancelButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(cancellationCalls, 1);
      expect(
        find.textContaining(OrderDetailStrings.cancelSessionFailure),
        findsOne,
      );

      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(orderCancelButtonKey));
      await tester.tap(find.byKey(orderCancelButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(cancellationCalls, 2);
    },
  );
}

class _EmptySupportRepository implements ParticipantSupportTicketRepository {
  const _EmptySupportRepository();

  @override
  Future<SupportTicket> create(SupportTicketDraft draft) =>
      throw UnsupportedError('Not used by this test.');

  @override
  Future<List<SupportTicket>> fetchForOrder(String orderId) async => const [];

  @override
  Stream<List<SupportTicket>> watchForOrder(String orderId) =>
      const Stream.empty();
}

class _EmptyRiskRepository implements ParticipantRiskReportQueryRepository {
  const _EmptyRiskRepository();

  @override
  Future<List<ParticipantRiskReportSummary>> fetchForOrder(
    String orderId,
  ) async => const [];

  @override
  Stream<List<ParticipantRiskReportSummary>> watchForOrder(String orderId) =>
      const Stream.empty();

  @override
  Future<ParticipantRiskReportSummary?> findActive(
    String orderId,
    RiskCategory category,
  ) async => null;

  @override
  Future<List<RiskReportEvent>> fetchEvents(String reportId) async => const [];
}

class _NoopRealtimeService extends RealtimeService {
  _NoopRealtimeService(SupabaseClient client) : super(client: client);

  @override
  Future<void> broadcastOrderCancelled(
    DriverOrderCancellationEvent event,
  ) async {}
}

OrderModel _order({String status = 'delivering'}) {
  final now = DateTime(2026, 7, 29, 10, 30);
  return OrderModel(
    id: 'order-12345678',
    customerId: 'customer-1',
    status: status,
    pickupAddress: '12 Nguyễn Trãi, Quận 1',
    pickupLat: 10.76,
    pickupLng: 106.66,
    deliveryAddress: '58 Lê Lợi, Quận 3',
    deliveryLat: 10.78,
    deliveryLng: 106.68,
    totalPrice: 85000,
    note: 'Gọi người nhận trước khi giao.',
    createdAt: now.subtract(const Duration(minutes: 8)),
    trackingCode: 'GH-2026-001',
    recipientName: 'Nguyễn Minh Anh',
    recipientPhone: '0901 234 567',
    itemName: 'Bánh kem sinh nhật',
    itemCategory: 'food',
    itemDescription: 'Giữ hộp thẳng và giao nhẹ tay',
    deliveryFee: 85000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    updatedAt: now,
  );
}
