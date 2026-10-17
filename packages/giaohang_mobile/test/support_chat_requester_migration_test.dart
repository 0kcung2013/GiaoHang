import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '../../supabase/migrations/'
    '20260828064310_support_chat_requesters.sql',
  );

  test('reuses support tables for customer and driver requesters', () {
    final sql = migration.readAsStringSync().toLowerCase();

    expect(sql, contains('rename column customer_id to requester_id'));
    expect(sql, contains("'customer', 'driver', 'support', 'admin'"));
    expect(sql, contains('ticket.requester_id <> actor_id'));
    expect(sql, contains("p_visibility <> 'public'"));
    expect(sql, contains("'người dùng vừa phản hồi'"));
    expect(sql, isNot(contains('create table')));
  });

  test('requester and staff policies keep row ownership checks', () {
    final sql = migration.readAsStringSync().toLowerCase();

    expect(sql, contains('requester_id = (select auth.uid())'));
    expect(sql, contains('ticket.requester_id = (select auth.uid())'));
    expect(sql, contains('support_ticket_messages_requester_or_staff_select'));
    expect(
      sql,
      contains('revoke all on function public.post_support_ticket_message'),
    );
  });
}
