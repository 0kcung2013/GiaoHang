import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/core/widgets/admin_workspace_scope.dart';
import 'package:operations_web/features/support/data/support_ticket_repository.dart';
import 'package:operations_web/features/support/models/support_ticket.dart';
import 'package:operations_web/features/support/screens/support_home_screen.dart';
import 'helpers/admin_test_fixtures.dart';

void main() {
  setUpAll(loadAdminTestFonts);
  testWidgets(
    'admin waiting queue includes order, general and monitoring cases only awaiting a decision',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Tickets();
      await tester.pumpWidget(
        adminTestApp(
          AdminWorkspaceScope(
            child: SupportHomeScreen(
              repository: repository,
              currentUserId: 'admin-1',
              isAdmin: true,
              waitingAdminOnly: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chờ duyệt xử lý đơn'), findsOneWidget);
      expect(find.text('Chờ duyệt yêu cầu chung'), findsOneWidget);
      expect(find.text('Giám sát: cần Admin xác minh'), findsOneWidget);
      expect(find.text('Yêu cầu mới thông thường'), findsNothing);
      expect(find.text('Hồ sơ đã kết thúc'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        adminTestApp(
          AdminWorkspaceScope(
            child: SupportHomeScreen(
              repository: repository,
              currentUserId: 'admin-1',
              isAdmin: true,
              waitingAdminOnly: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Yêu cầu mới thông thường'), findsOneWidget);
      expect(repository.reads, 1);
    },
  );
}

class _Tickets extends Fake implements SupportTicketRepository {
  int reads = 0;
  @override
  Future<List<SupportTicket>> fetchTickets() async {
    reads++;
    return [
      _ticket(
        '1',
        'Chờ duyệt xử lý đơn',
        SupportTicketStatus.waitingAdmin,
        orderId: 'order-1',
      ),
      _ticket('2', 'Chờ duyệt yêu cầu chung', SupportTicketStatus.waitingAdmin),
      _ticket(
        '3',
        'Giám sát: cần Admin xác minh',
        SupportTicketStatus.waitingAdmin,
        orderId: 'order-2',
      ),
      _ticket('4', 'Yêu cầu mới thông thường', SupportTicketStatus.open),
      _ticket('5', 'Hồ sơ đã kết thúc', SupportTicketStatus.resolved),
    ];
  }
}

SupportTicket _ticket(
  String id,
  String subject,
  SupportTicketStatus status, {
  String? orderId,
}) => SupportTicket(
  id: id,
  requesterId: 'customer-1',
  subject: subject,
  message: 'Đối chiếu trước khi quyết định',
  status: status,
  priority: SupportTicketPriority.normal,
  orderId: orderId,
  createdAt: DateTime.utc(2026, 10, 20),
  updatedAt: DateTime.utc(2026, 10, 20),
);
