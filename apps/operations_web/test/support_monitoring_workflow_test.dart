import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:operations_web/features/support/data/support_ticket_repository.dart';
import 'package:operations_web/features/support/dialogs/support_ticket_detail_dialog.dart';
import 'package:operations_web/features/support/models/support_queue_scope.dart';
import 'package:operations_web/features/support/models/support_ticket.dart';
import 'package:operations_web/features/support/screens/support_home_screen.dart';

const automaticBody =
    'Tài xế chưa xuất phát sau 10 phút.\n'
    'Chưa nhận hàng. Hệ thống thu hồi phân công và tìm tài xế thay thế. '
    'Không tính là lượt từ chối.';

SupportTicket monitoringTicket([Map<String, dynamic> overrides = const {}]) =>
    SupportTicket.fromJson({
      'id': 'automatic',
      'requester_id': 'former-driver',
      'requester_role': 'driver',
      'order_id': 'order-1',
      'tracking_code': 'GH-10216',
      'subject': 'Giám sát: thu hồi phân công',
      'message': automaticBody,
      'last_message_role': 'system',
      'last_message_body': automaticBody,
      'status': 'open',
      'priority': 'high',
      'created_at': '2026-10-11T07:00:00Z',
      'updated_at': '2026-10-11T07:00:00Z',
      ...overrides,
    });

void main() {
  test(
    'only unattended automatic reclamation leaves the intervention queue',
    () {
      final automatic = monitoringTicket();
      expect(automatic.isAutomaticMonitoringNotice, isTrue);
      expect(automatic.needsReply, isFalse);
      expect(SupportQueueScope.active.includes(automatic, 'staff'), isFalse);
      expect(
        SupportQueueScope.unassigned.includes(automatic, 'staff'),
        isFalse,
      );
      expect(SupportQueueScope.automatic.includes(automatic, 'staff'), isTrue);
      for (final overrides in [
        {'last_message_role': 'driver'},
        {'last_message_role': 'customer'},
        {
          'human_messages': [
            {'id': 'earlier-human-reply'},
          ],
        },
        {'assigned_to': 'staff'},
        {'first_response_at': '2026-10-11T07:01:00Z'},
        {'risk_report_id': 'risk'},
        {'subject': 'Giám sát: mất GPS khi đang giữ hàng'},
        {
          'last_message_body':
              'Hàng đã nhận. Giữ tài xế; CSKH cần liên hệ xác minh.',
        },
        {'message': 'Unknown event', 'last_message_body': 'Unknown event'},
      ]) {
        final ticket = monitoringTicket(overrides);
        expect(
          ticket.isAutomaticMonitoringNotice,
          isFalse,
          reason: '$overrides',
        );
        expect(
          SupportQueueScope.active.includes(ticket, 'staff'),
          isTrue,
          reason: '$overrides',
        );
      }
      final restored = SupportTicket.fromJson(
        monitoringTicket({
          'human_messages': [
            {'id': 'human'},
          ],
        }).toJson(),
      );
      expect(restored.hasHumanConversation, isTrue);
      expect(restored.isAutomaticMonitoringNotice, isFalse);
    },
  );

  test(
    'queue and detail query retain earlier human replies independently of latest system message',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        httpClient: MockClient((request) async {
          final isDetail = request.url.queryParameters['id'] == 'eq.automatic';
          final Object data;
          if (request.url.path.endsWith('/support_tickets')) {
            expect(
              request.url.queryParameters['select'],
              contains('human_messages:case_messages(id)'),
            );
            expect(
              request
                  .url
                  .queryParameters['human_messages.sender_role_snapshot'],
              'neq.system',
            );
            expect(request.url.queryParameters['human_messages.limit'], '1');
            expect(request.url.queryParameters['last_message.limit'], '1');
            final row = {
              ...monitoringTicket().toJson(),
              'human_messages': [
                {'id': 'human-before-system'},
              ],
              'last_message': [
                {'body': automaticBody, 'sender_role_snapshot': 'system'},
              ],
            };
            data = isDetail
                ? row
                : request.url.queryParameters.containsKey('id')
                ? <Object>[]
                : [row];
          } else if (request.url.path.endsWith(
            '/get_support_ticket_contacts',
          )) {
            data = <Object>[];
          } else {
            throw StateError('Unexpected ${request.url.path}');
          }
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseSupportTicketRepository(client);
      for (final ticket in [
        await repository.fetchTicket('automatic'),
        ...(await repository.fetchTickets()),
      ]) {
        expect(ticket.hasHumanConversation, isTrue);
        expect(ticket.needsSupportAttention, isTrue);
      }
    },
  );

  for (final viewport in [
    (size: const Size(1280, 850), scale: 1.0),
    (size: const Size(375, 568), scale: 1.6),
  ]) {
    testWidgets('monitoring queue separates automatic history at $viewport', (
      tester,
    ) async {
      tester.view.physicalSize = viewport.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = MonitoringRepository();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(viewport.scale)),
            child: child!,
          ),
          home: SupportHomeScreen(
            repository: repository,
            currentUserId: 'staff',
            monitoring: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cần can thiệp · 1'), findsOneWidget);
      expect(find.text('Nhật ký tự động · 1'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Giám sát: mất GPS khi đang giữ hàng'),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('support-ticket-scroll-view')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Giám sát: mất GPS khi đang giữ hàng'), findsOneWidget);
      expect(find.text('Đã thu hồi phân công'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const Key('support-queue-automatic')),
      );
      await tester.tap(find.byKey(const Key('support-queue-automatic')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Đã thu hồi phân công'),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('support-ticket-scroll-view')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Đã thu hồi phân công'), findsOneWidget);
      expect(find.text('Không cần tiếp nhận'), findsOneWidget);
      expect(find.text('Ưu tiên cao'), findsNothing);
      expect(find.text('Cần phản hồi'), findsNothing);
      expect(repository.commands, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'automatic detail explains outcome without requiring acceptance at $viewport',
      (tester) async {
        tester.view.physicalSize = viewport.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = MonitoringRepository();
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(viewport.scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SupportTicketDetailDialog(
                ticket: monitoringTicket(),
                currentUserId: 'staff',
                isAdmin: false,
                repository: repository,
                embedded: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('accept-support-ticket')), findsNothing);
        expect(find.textContaining('Chỉ ghi nhận tự động'), findsOneWidget);
        expect(find.text('Nhận xử lý hồ sơ để bắt đầu phản hồi'), findsNothing);
        expect(repository.commands, 0);
        final intervene = find.byKey(
          const Key('start-monitoring-intervention'),
        );
        await tester.ensureVisible(intervene);
        await tester.tap(intervene);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('accept-support-ticket')), findsOneWidget);
        expect(repository.commands, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class MonitoringRepository
    implements SupportTicketRepository, SupportTicketConversationRepository {
  int commands = 0;
  @override
  Future<List<SupportTicket>> fetchTickets() async => [
    monitoringTicket(),
    monitoringTicket({
      'id': 'custody',
      'subject': 'Giám sát: mất GPS khi đang giữ hàng',
      'message': 'Mất GPS khi đã nhận hàng; CSKH cần liên hệ xác minh.',
      'last_message_body':
          'Mất GPS khi đã nhận hàng; CSKH cần liên hệ xác minh.',
    }),
  ];
  @override
  Future<List<CaseMessage>> fetchMessages(String ticketId) async => [
    CaseMessage(
      id: 'system',
      caseId: ticketId,
      senderId: 'former-driver',
      senderRole: 'system',
      visibility: CaseMessageVisibility.public,
      body: ticketId == 'custody'
          ? 'Không nhận được GPS hợp lệ trong 10 phút. Hàng đã nhận. CSKH cần liên hệ xác minh.'
          : automaticBody,
      createdAt: DateTime(2026, 10, 11),
    ),
  ];
  @override
  Stream<List<CaseMessage>> watchMessages(String ticketId) =>
      const Stream.empty();
  @override
  Future<void> postMessage(
    String ticketId,
    String body, {
    required CaseMessageVisibility visibility,
  }) async {
    commands++;
  }

  @override
  Future<void> createTicket(SupportTicketDraft draft, String actorId) async {
    commands++;
  }

  @override
  Future<void> updateStatus(String ticketId, SupportTicketStatus status) async {
    commands++;
  }
}
