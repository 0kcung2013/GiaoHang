import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_mobile/core/providers/customer_providers.dart';
import 'package:giaohang_mobile/features/customer/screens/account/customer_requests_screen.dart';
import 'package:giaohang_mobile/features/customer/screens/account/data/customer_support_inbox_repository.dart';
import 'package:giaohang_mobile/features/customer/screens/account/providers/customer_account_providers.dart';
import 'package:giaohang_mobile/features/customer/screens/account/constants/customer_account_strings.dart';
import 'package:giaohang_mobile/features/order_help/data/customer_support_ticket_repository.dart';
import 'helpers/customer_account_fixtures.dart';

void main() {
  setUpAll(loadCustomerAccountTestFonts);

  testWidgets(
    'an older inbox response cannot overwrite a newly selected status',
    (tester) async {
      final repository = _Inbox();
      final old = Completer<List<SupportTicket>>();
      repository.open = old.future;
      await tester.pumpWidget(_app(repository));
      await tester.pump();
      await tester.tap(
        find.widgetWithText(ChoiceChip, CustomerAccountStrings.closedRequests),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hồ sơ đã xử lý'), findsOneWidget);
      old.complete([_ticket('Hồ sơ cũ')]);
      await tester.pumpAndSettle();
      expect(find.text('Hồ sơ đã xử lý'), findsOneWidget);
      expect(find.text('Hồ sơ cũ'), findsNothing);
    },
  );

  testWidgets(
    'a failed inbox load can be retried without opening a new conversation',
    (tester) async {
      final repository = _Inbox()..fail = true;
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      expect(find.text(CustomerAccountStrings.requestsError), findsOneWidget);
      repository.fail = false;
      await tester.tap(find.text(CustomerAccountStrings.retry));
      await tester.pumpAndSettle();
      expect(find.text('Hồ sơ đang xử lý'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _app(_Inbox repository) => ProviderScope(
  overrides: [
    customerAccountUserIdProvider.overrideWithValue('actor-1'),
    notificationsProvider('actor-1').overrideWith((_) async => []),
  ],
  child: MaterialApp(home: CustomerRequestsScreen(repository: repository)),
);

SupportTicket _ticket(String subject, {bool closed = false}) => SupportTicket(
  id: subject,
  requesterId: 'actor-1',
  subject: subject,
  message: 'Nội dung hỗ trợ',
  status: closed ? SupportTicketStatus.resolved : SupportTicketStatus.open,
  priority: SupportTicketPriority.normal,
  createdAt: DateTime.utc(2026, 10, 22),
  updatedAt: DateTime.utc(2026, 10, 22),
);

class _Inbox implements CustomerSupportInboxRepository {
  Future<List<SupportTicket>>? open;
  bool fail = false;
  @override
  Future<List<SupportTicket>> fetch({
    bool closed = false,
    int offset = 0,
  }) async {
    if (fail) throw Exception('offline');
    return closed
        ? [_ticket('Hồ sơ đã xử lý', closed: true)]
        : await (open ?? Future.value([_ticket('Hồ sơ đang xử lý')]));
  }

  @override
  ParticipantSupportTicketRepository get conversations =>
      throw UnimplementedError();
}
