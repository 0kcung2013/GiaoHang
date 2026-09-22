import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:operations_web/features/support/data/support_ticket_repository.dart';
import 'package:operations_web/features/support/dialogs/support_ticket_detail_dialog.dart';
import 'package:operations_web/features/support/widgets/support_live_conversation.dart';

void main() {
  testWidgets('orders messages oldest to newest from top to bottom', (
    tester,
  ) async {
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
            width: 760,
            height: 680,
            child: SupportLiveConversation(
              messages: [newer, older],
              currentUserId: 'support-1',
              canReply: true,
              onSend: (_, _) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Tin cũ hơn')).dy,
      lessThan(tester.getTopLeft(find.text('Tin mới nhất')).dy),
    );
  });

  testWidgets('support detail keeps case context beside a focused chat', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ticket = SupportTicket(
      id: 'ticket-1',
      requesterId: 'driver-1',
      requesterRole: 'driver',
      requesterName: 'Nguyễn Văn A',
      assignedTo: 'support-1',
      assignedToName: 'Chăm sóc khách hàng',
      orderId: 'order-1',
      subject: 'Trao đổi với CSKH',
      message: 'Tôi cần hỗ trợ giao hàng.',
      status: SupportTicketStatus.inProgress,
      priority: SupportTicketPriority.normal,
      createdAt: DateTime(2026, 9, 16, 10),
      updatedAt: DateTime(2026, 9, 16, 11),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupportTicketDetailDialog(
            ticket: ticket,
            currentUserId: 'support-1',
            isAdmin: false,
            repository: _FakeSupportRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vấn đề cần hỗ trợ'), findsOneWidget);
    expect(find.text('Hội thoại'), findsOneWidget);
    expect(find.text('Thời gian thực'), findsOneWidget);
    expect(find.byKey(const Key('support-case-message-field')), findsOneWidget);
    expect(find.text('Trao đổi hồ sơ'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _FakeSupportRepository
    implements SupportTicketRepository, SupportTicketConversationRepository {
  @override
  Future<void> createTicket(SupportTicketDraft draft, String actorId) async {}

  @override
  Future<List<SupportTicket>> fetchTickets() async => const [];

  @override
  Future<void> updateStatus(
    String ticketId,
    SupportTicketStatus status,
  ) async {}

  @override
  Future<List<CaseMessage>> fetchMessages(String ticketId) async => const [];

  @override
  Future<void> postMessage(
    String ticketId,
    String body, {
    required CaseMessageVisibility visibility,
  }) async {}

  @override
  Stream<List<CaseMessage>> watchMessages(String ticketId) =>
      const Stream.empty();
}
