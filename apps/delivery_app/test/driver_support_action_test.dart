import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/driver/screens/home/widgets/driver_order_card.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_help_actions.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_navigation_view.dart';
import 'package:delivery_app/features/order_help/data/customer_support_ticket_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  testWidgets('driver support is separate from incident reporting', (
    tester,
  ) async {
    final repository = _FakeParticipantSupportRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverHelpActionsForTest(order: _order, repository: repository),
        ),
      ),
    );

    expect(find.text('Trao đổi với CSKH'), findsOneWidget);
    expect(find.text('Báo cáo sự cố'), findsOneWidget);

    await tester.tap(find.text('Trao đổi với CSKH'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('customer-support-message')),
      'Tôi cần CSKH hỗ trợ giao đơn này.',
    );
    await tester.tap(find.byKey(const Key('submit-customer-support-ticket')));
    await tester.pumpAndSettle();

    expect(repository.created, hasLength(1));
    expect(repository.created.single.requesterId, 'driver-1');
    expect(repository.created.single.orderId, 'order-1');
  });

  testWidgets('navigation condenses help actions into one map control', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverHelpActions(
            order: _order,
            collapsed: true,
            supportRepository: _FakeParticipantSupportRepository(),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('driver-help-menu-button')), findsOneWidget);
    expect(find.text('Trao đổi với CSKH'), findsNothing);
    expect(find.text('Báo cáo sự cố'), findsNothing);

    await tester.tap(find.byKey(const Key('driver-help-menu-button')));
    await tester.pumpAndSettle();

    expect(find.text('Hỗ trợ chuyến đi'), findsOneWidget);
    expect(find.text('Trao đổi với CSKH'), findsOneWidget);
    expect(find.text('Báo cáo sự cố'), findsOneWidget);
    expect(find.byKey(const Key('driver-help-support-option')), findsOneWidget);
    expect(find.byKey(const Key('driver-help-risk-option')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('driver order card omits support and incident actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DriverOrderCard(
                order: _order.copyWith(status: 'assigned'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Mở quy trình giao hàng'), findsOneWidget);
    expect(find.text('Trao đổi với CSKH'), findsNothing);
    expect(find.text('Báo cáo sự cố'), findsNothing);
  });

  testWidgets('driver navigation keeps support and incident actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DriverNavigationView(
          order: _order.copyWith(status: 'assigned'),
          map: const ColoredBox(color: Colors.white),
          arrivedAtTarget: false,
          isUpdatingStatus: false,
          onBack: () {},
          onFitMap: () {},
          onPrimaryAction: () {},
        ),
      ),
    );

    expect(find.byKey(const Key('driver-help-menu-button')), findsOneWidget);
    expect(find.text('Trao đổi với CSKH'), findsNothing);
    expect(find.text('Báo cáo sự cố'), findsNothing);

    await tester.tap(find.byKey(const Key('driver-help-menu-button')));
    await tester.pumpAndSettle();

    expect(find.text('Trao đổi với CSKH'), findsOneWidget);
    expect(find.text('Báo cáo sự cố'), findsOneWidget);
  });
}

class DriverHelpActionsForTest extends StatelessWidget {
  const DriverHelpActionsForTest({
    required this.order,
    required this.repository,
    super.key,
  });

  final OrderModel order;
  final ParticipantSupportTicketRepository repository;

  @override
  Widget build(BuildContext context) =>
      DriverHelpActions(order: order, supportRepository: repository);
}

class _FakeParticipantSupportRepository
    implements ParticipantSupportTicketRepository {
  final created = <SupportTicketDraft>[];

  @override
  Future<SupportTicket> create(SupportTicketDraft draft) async {
    created.add(draft);
    return SupportTicket(
      id: 'ticket-1',
      requesterId: draft.requesterId,
      requesterRole: 'driver',
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
