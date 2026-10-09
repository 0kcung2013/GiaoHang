import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/support/data/support_ticket_repository.dart';
import 'package:operations_web/features/support/dialogs/support_ticket_detail_dialog.dart';
import 'package:operations_web/features/support/models/support_ticket.dart';

void main() {
  testWidgets('short viewport keeps chat usable at enlarged text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(540, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository()
      ..update(SupportTicketStatus.inProgress, owner: 'staff');
    addTearDown(repository.changes.close);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: SupportTicketDetailDialog(
            ticket: repository.ticket,
            currentUserId: 'staff',
            isAdmin: false,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-case-message-field')), findsOneWidget);
  });

  testWidgets('accept, finish and reopen preserve the open case', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository();
    addTearDown(repository.changes.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupportTicketDetailDialog(
            ticket: repository.ticket,
            currentUserId: 'staff',
            isAdmin: false,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accept-support-ticket')));
    await tester.pumpAndSettle();
    expect(find.byType(SupportTicketDetailDialog), findsOneWidget);
    expect(find.byKey(const Key('support-case-message-field')), findsOneWidget);
    await tester.tap(find.byKey(const Key('finish-support-ticket')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('support-resolution-field')),
      'Đã xác minh và hỗ trợ xong.',
    );
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(repository.ticket.status, SupportTicketStatus.resolved);
    expect(find.byType(SupportTicketDetailDialog), findsOneWidget);
    expect(find.byKey(const Key('support-case-message-field')), findsNothing);
    await tester.tap(find.text('Mở lại'));
    await tester.pumpAndSettle();
    expect(repository.ticket.status, SupportTicketStatus.inProgress);
    expect(find.byKey(const Key('support-case-message-field')), findsOneWidget);
  });

  testWidgets('remote ownership change disables reply without losing case', (
    tester,
  ) async {
    final repository = _Repository()
      ..update(SupportTicketStatus.inProgress, owner: 'staff');
    addTearDown(repository.changes.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupportTicketDetailDialog(
            ticket: repository.ticket,
            currentUserId: 'staff',
            isAdmin: false,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    repository.update(SupportTicketStatus.inProgress, owner: 'other');
    repository.changes.add(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-case-message-field')), findsNothing);
    expect(find.byType(SupportTicketDetailDialog), findsOneWidget);
  });
}

class _Repository
    implements
        SupportTicketRepository,
        SupportTicketCommandRepository,
        SupportTicketConversationRepository,
        SupportTicketDetailRepository {
  final changes = StreamController<void>.broadcast();
  SupportTicket ticket = SupportTicket(
    id: 'ticket',
    requesterId: 'customer',
    subject: 'Hỗ trợ giao hàng',
    message: 'Tôi cần hỗ trợ.',
    status: SupportTicketStatus.open,
    priority: SupportTicketPriority.normal,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  void update(SupportTicketStatus status, {String? owner, String? resolution}) {
    ticket = SupportTicket.fromJson({
      ...ticket.toJson(),
      'status': status.databaseValue,
      'assigned_to': owner ?? ticket.assignedTo,
      'resolution': resolution ?? ticket.resolution,
    });
  }

  @override
  Future<SupportTicket> fetchTicket(String id) async => ticket;
  @override
  Stream<void> watchTicket(String id) => changes.stream;
  @override
  Future<List<SupportTicket>> fetchTickets() async => [ticket];
  @override
  Future<void> acceptTicket(String id) async =>
      update(SupportTicketStatus.inProgress, owner: 'staff');
  @override
  Future<void> takeOverTicket(String id) async {}
  @override
  Future<void> transitionTicket(
    String id,
    SupportTicketStatus status, {
    String? resolution,
  }) async => update(status, resolution: resolution);
  @override
  Future<void> updateStatus(String id, SupportTicketStatus status) async =>
      update(status);
  @override
  Future<void> createTicket(SupportTicketDraft draft, String actorId) async {}
  @override
  Future<List<CaseMessage>> fetchMessages(String id) async => [];
  @override
  Stream<List<CaseMessage>> watchMessages(String id) => const Stream.empty();
  @override
  Future<void> postMessage(
    String id,
    String body, {
    required CaseMessageVisibility visibility,
  }) async {}
}
