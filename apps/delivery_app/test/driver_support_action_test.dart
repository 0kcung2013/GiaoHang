import 'dart:async';

import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/driver/screens/home/widgets/driver_order_card.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_help_actions.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_navigation_view.dart';
import 'package:delivery_app/features/order_help/data/customer_support_ticket_repository.dart';
import 'package:delivery_app/features/order_help/widgets/support_chat/support_chat_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  for (final sameIssue in [true, false]) {
    testWidgets(
      'driver reuses an active conversation regardless of its original subject ($sameIssue)',
      (tester) async {
        final repository = _FakeParticipantSupportRepository();
        repository.existing = [
          SupportTicket.fromJson({
            'id': 'existing-ticket',
            'requester_id': 'driver-1',
            'order_id': 'order-1',
            'subject': sameIssue
                ? 'Không liên hệ được người nhận'
                : 'Thanh toán hoặc phí',
            'message': 'Thông tin yêu cầu trước',
            'status': 'in_progress',
          }),
        ];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DriverHelpActionsForTest(
                order: _order,
                repository: repository,
              ),
            ),
          ),
        );
        await tester.tap(find.text('Trao đổi với CSKH'));
        await tester.pumpAndSettle();
        expect(find.text('Đang xử lý'), findsOneWidget);
        expect(repository.created, isEmpty);
      },
    );
  }

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
    expect(find.byKey(const Key('support-chat-sheet')), findsOneWidget);
    expect(find.text('CSKH GiaoHang'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('support-chat-composer')),
      'Tôi cần CSKH hỗ trợ giao đơn này.',
    );
    await tester.tap(find.byKey(const Key('send-support-chat-message')));
    await tester.pumpAndSettle();

    expect(repository.created, hasLength(1));
    expect(repository.created.single.requesterId, 'driver-1');
    expect(repository.created.single.orderId, 'order-1');
    expect(repository.created.single.subject, 'Trao đổi với CSKH');
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

  testWidgets('support chat receives CSKH replies in real time', (
    tester,
  ) async {
    final repository = _RealtimeParticipantSupportRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverHelpActionsForTest(order: _order, repository: repository),
        ),
      ),
    );

    await tester.tap(find.text('Trao đổi với CSKH'));
    await tester.pumpAndSettle();

    expect(find.text('Đang chờ cập nhật · Chạm để tải lại'), findsOneWidget);
    repository.emitSupportReply('CSKH đang kiểm tra đơn hàng cho bạn.');
    await tester.pumpAndSettle();

    expect(find.text('CSKH đang kiểm tra đơn hàng cho bạn.'), findsOneWidget);

    await tester.tap(find.byTooltip('Đóng cuộc trò chuyện'));
    await tester.pumpAndSettle();
    await repository.dispose();
  });

  testWidgets('mobile support chat keeps the newest message at the bottom', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    final newer = CaseMessage(
      id: 'newer',
      caseId: 'ticket-1',
      senderId: 'driver-1',
      senderRole: 'driver',
      visibility: CaseMessageVisibility.public,
      body: 'Tin mới nhất',
      createdAt: DateTime(2026, 9, 16, 13, 49),
    );
    final older = CaseMessage(
      id: 'older',
      caseId: 'ticket-1',
      senderId: 'driver-1',
      senderRole: 'driver',
      visibility: CaseMessageVisibility.public,
      body: 'Tin cũ hơn',
      createdAt: DateTime(2026, 9, 16, 10, 59),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 620,
            child: SupportChatMessages(
              messages: [newer, older],
              requesterId: 'driver-1',
              scrollController: scrollController,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('Tin cũ hơn')).dy,
      lessThan(tester.getTopLeft(find.text('Tin mới nhất')).dy),
    );
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
  List<SupportTicket> existing = const [];

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
  Future<List<SupportTicket>> fetchForOrder(String orderId) async => existing;

  @override
  Stream<List<SupportTicket>> watchForOrder(String orderId) =>
      const Stream.empty();
}

class _RealtimeParticipantSupportRepository
    implements
        ParticipantSupportTicketRepository,
        ParticipantSupportConversationRepository {
  final _messageController = StreamController<List<CaseMessage>>.broadcast();
  final _ticket = SupportTicket(
    id: 'ticket-live',
    requesterId: 'driver-1',
    requesterRole: 'driver',
    orderId: 'order-1',
    subject: 'Trao đổi với CSKH',
    message: 'Tôi cần hỗ trợ đơn hàng.',
    status: SupportTicketStatus.inProgress,
    priority: SupportTicketPriority.normal,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  List<CaseMessage> _messages = const [];

  void emitSupportReply(String body) {
    _messages = [
      ..._messages,
      CaseMessage(
        id: 'message-${_messages.length + 1}',
        caseId: _ticket.id,
        senderId: 'support-1',
        senderRole: 'support',
        visibility: CaseMessageVisibility.public,
        body: body,
        createdAt: DateTime(2026, 9, 16, 10, 30),
      ),
    ];
    _messageController.add(_messages);
  }

  Future<void> dispose() => _messageController.close();

  @override
  Future<SupportTicket> create(SupportTicketDraft draft) async => _ticket;

  @override
  Future<List<SupportTicket>> fetchForOrder(String orderId) async => [_ticket];

  @override
  Stream<List<SupportTicket>> watchForOrder(String orderId) =>
      const Stream.empty();

  @override
  Future<List<CaseMessage>> fetchMessages(String ticketId) async => _messages;

  @override
  Stream<List<CaseMessage>> watchMessages(String ticketId) =>
      _messageController.stream;

  @override
  Future<void> postMessage(String ticketId, String body) async {}
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
