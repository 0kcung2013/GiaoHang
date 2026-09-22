import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/providers/customer_providers.dart';
import 'package:delivery_app/features/customer/screens/order/dialogs/order_detail_sheet.dart';
import 'package:delivery_app/features/customer/screens/order/dialogs/order_detail_strings.dart';
import 'package:delivery_app/features/customer/screens/order/dialogs/widgets/order_cancel_section.dart';
import 'package:delivery_app/features/order_help/data/customer_support_ticket_repository.dart';
import 'package:delivery_app/features/risk_reports/data/participant_risk_report_query_repository.dart';
import 'package:delivery_app/features/risk_reports/models/participant_risk_report_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  for (final confirmed in [false, true]) {
    testWidgets(
      'picking_up cancellation locked only when confirmed=$confirmed',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final order = OrderModel(
          id: 'order-1',
          trackingCode: 'GH-TEST-1',
          customerId: 'customer-1',
          driverId: 'driver-1',
          status: 'picking_up',
          pickupAddress: 'Điểm lấy hàng',
          pickupLat: 11.02,
          pickupLng: 106.62,
          deliveryAddress: 'Điểm giao hàng',
          deliveryLat: 11.03,
          deliveryLng: 106.63,
          totalPrice: 25000,
          deliveryFee: 25000,
          serviceType: 'standard',
          paymentMethod: 'cash',
          createdAt: DateTime(2026, 9, 15),
          updatedAt: DateTime(2026, 9, 15),
          actualPickedUpAt: confirmed ? DateTime(2026, 9, 15, 10) : null,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              orderItemsProvider.overrideWith((ref, id) async => const []),
              orderStatusLogsProvider.overrideWith((ref, id) async => const []),
              orderDeliveryProofsProvider.overrideWith(
                (ref, id) async => const [],
              ),
              assignedDriverProvider.overrideWith((ref, id) async => null),
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
        await tester.pumpAndSettle();
        await tester.dragUntilVisible(
          find.byKey(orderCancelButtonKey),
          find.byType(ListView),
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();
        final button = tester.widget<InkWell>(
          find.descendant(
            of: find.byKey(orderCancelButtonKey),
            matching: find.byType(InkWell),
          ),
        );
        expect(button.onTap, confirmed ? isNull : isNotNull);
        if (confirmed) {
          expect(
            find.text(OrderDetailStrings.cancelPickupLockedDescription),
            findsOneWidget,
          );
        } else {
          await tester.tap(find.byKey(orderCancelButtonKey));
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsOneWidget);
          expect(
            find.text(OrderDetailStrings.confirmCancelAction),
            findsOneWidget,
          );
        }
      },
    );
  }
}

class _EmptySupportRepository implements ParticipantSupportTicketRepository {
  const _EmptySupportRepository();
  @override
  Future<SupportTicket> create(SupportTicketDraft draft) =>
      throw UnsupportedError('Not used');
  @override
  Future<List<SupportTicket>> fetchForOrder(String id) async => const [];
  @override
  Stream<List<SupportTicket>> watchForOrder(String id) => const Stream.empty();
}

class _EmptyRiskRepository implements ParticipantRiskReportQueryRepository {
  const _EmptyRiskRepository();
  @override
  Future<List<ParticipantRiskReportSummary>> fetchForOrder(String id) async =>
      const [];
  @override
  Stream<List<ParticipantRiskReportSummary>> watchForOrder(String id) =>
      const Stream.empty();
  @override
  Future<ParticipantRiskReportSummary?> findActive(
    String id,
    RiskCategory category,
  ) async => null;
  @override
  Future<List<RiskReportEvent>> fetchEvents(String id) async => const [];
}
