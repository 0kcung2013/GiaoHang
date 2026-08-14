import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/support/data/support_ticket_repository.dart';
import 'package:operations_web/features/support/models/support_ticket.dart';
import 'package:operations_web/features/support/screens/support_home_screen.dart';

void main() {
  testWidgets('support workspace shows metrics and filters ticket queue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SupportHomeScreen(
          repository: _FakeSupportTicketRepository(),
          currentUserId: 'support-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trung tâm CSKH'), findsOneWidget);
    expect(find.text('Yêu cầu hỗ trợ'), findsOneWidget);
    expect(find.text('Ưu tiên cao'), findsOneWidget);
    expect(find.text('Không liên lạc được khách'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('support-ticket-search')),
      'thanh toán',
    );
    await tester.pump();

    expect(find.text('Không liên lạc được khách'), findsNothing);
    expect(find.text('Kiểm tra thanh toán COD'), findsOneWidget);
  });
}

class _FakeSupportTicketRepository implements SupportTicketRepository {
  @override
  Future<List<SupportTicket>> fetchTickets() async => [
    SupportTicket(
      id: 'ticket-1',
      customerId: 'customer-1',
      orderId: 'order-1',
      subject: 'Không liên lạc được khách',
      message: 'Tài xế cần CSKH xác minh số điện thoại.',
      status: SupportTicketStatus.open,
      priority: SupportTicketPriority.high,
      createdAt: DateTime(2026, 8, 12, 9),
      updatedAt: DateTime(2026, 8, 12, 10),
    ),
    SupportTicket(
      id: 'ticket-2',
      customerId: 'customer-2',
      subject: 'Kiểm tra thanh toán COD',
      message: 'Khách hàng cần đối soát khoản thu hộ.',
      status: SupportTicketStatus.inProgress,
      priority: SupportTicketPriority.normal,
      createdAt: DateTime(2026, 8, 12, 8),
      updatedAt: DateTime(2026, 8, 12, 11),
    ),
  ];

  @override
  Future<void> createTicket(SupportTicketDraft draft, String actorId) async {}

  @override
  Future<void> updateStatus(
    String ticketId,
    SupportTicketStatus status,
  ) async {}
}
