import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/customer_providers.dart';
import '../../../../core/mobile_app_role.dart';
import '../../../help_center/screens/general_support_chat_screen.dart';
import '../../../order_help/widgets/support_chat/support_chat_sheet.dart';
import 'constants/customer_account_strings.dart';
import 'data/customer_support_inbox_repository.dart';
import 'providers/customer_account_providers.dart';
import 'widgets/account_components.dart';
import 'widgets/customer_request_tile.dart';

class CustomerRequestsScreen extends ConsumerStatefulWidget {
  const CustomerRequestsScreen({super.key, this.repository});
  final CustomerSupportInboxRepository? repository;
  @override
  ConsumerState<CustomerRequestsScreen> createState() =>
      _CustomerRequestsScreenState();
}

class _CustomerRequestsScreenState
    extends ConsumerState<CustomerRequestsScreen> {
  late final _repository =
      widget.repository ??
      SupabaseCustomerSupportInboxRepository(Supabase.instance.client);
  List<SupportTicket> _rows = [];
  bool _closed = false,
      _loading = true,
      _more = false,
      _hasMore = false,
      _failed = false;
  int _revision = 0, _offset = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loading || _more || !_hasMore)) return;
    final revision = ++_revision;
    setState(() {
      _failed = false;
      if (more) {
        _more = true;
      } else {
        _loading = true;
        _rows = [];
        _offset = 0;
      }
    });
    try {
      final rows = await _repository.fetch(closed: _closed, offset: _offset);
      if (!mounted || revision != _revision) return;
      setState(() {
        _offset += rows.length;
        _rows = {
          for (final row in [..._rows, ...rows]) row.id: row,
        }.values.toList();
        _hasMore =
            rows.length == SupabaseCustomerSupportInboxRepository.pageSize;
      });
    } catch (_) {
      if (mounted && revision == _revision) setState(() => _failed = true);
    } finally {
      if (mounted && revision == _revision) {
        setState(() {
          _loading = false;
          _more = false;
        });
      }
    }
  }

  Future<void> _markRead(String ticketId) async {
    final id = ref.read(customerAccountUserIdProvider);
    if (id == null) return;
    try {
      final notifications = await ref.read(notificationsProvider(id).future);
      await Future.wait(
        notifications
            .where((n) => n.supportTicketId == ticketId && !n.isRead)
            .map(
              (n) => ref.read(notificationServiceProvider).markAsRead(n.id, id),
            ),
      );
      if (!mounted) return;
      ref.invalidate(notificationsProvider(id));
      ref.invalidate(unreadNotificationCountProvider(id));
    } catch (_) {
      // A notification failure must not prevent the requester opening their case.
    }
  }

  Future<void> _open(SupportTicket ticket) async {
    final id = ref.read(customerAccountUserIdProvider);
    if (id == null) return;
    unawaited(_markRead(ticket.id));
    await showParticipantSupportChatSheet(
      context,
      requesterId: id,
      requesterRole: 'customer',
      orderId: ticket.orderId,
      subject: ticket.subject,
      priority: ticket.priority,
      repository: _repository.conversations,
      initialTicket: ticket,
    );
    if (mounted) await _load();
  }

  Future<void> _newRequest() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            const GeneralSupportChatScreen(role: MobileAppRole.customer),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(customerAccountUserIdProvider);
    final unread = id == null
        ? <String>{}
        : (ref.watch(notificationsProvider(id)).valueOrNull ?? [])
              .where((n) => !n.isRead && n.supportTicketId != null)
              .map((n) => n.supportTicketId!)
              .toSet();
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text(
          CustomerAccountStrings.requests,
          style: AppTextStyles.headingMedium,
        ),
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: AppColors.bgCard,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final closed in [false, true])
                        ChoiceChip(
                          label: Text(
                            closed
                                ? CustomerAccountStrings.closedRequests
                                : CustomerAccountStrings.openRequests,
                          ),
                          selected: _closed == closed,
                          selectedColor: AppColors.accentLight,
                          onSelected: (_) {
                            if (_closed == closed) return;
                            setState(() => _closed = closed);
                            _load();
                          },
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenH,
                      ),
                      children: [
                        if (_loading)
                          const LinearProgressIndicator(
                            color: AppColors.accent,
                          ),
                        if (_failed)
                          CustomerAccountState(
                            message: CustomerAccountStrings.requestsError,
                            onRetry: () => _load(more: _rows.isNotEmpty),
                          ),
                        if (!_loading && !_failed && _rows.isEmpty)
                          const CustomerAccountState(
                            message: CustomerAccountStrings.noRequestsHint,
                          ),
                        for (final ticket in _rows)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: CustomerRequestTile(
                              ticket: ticket,
                              unread: unread.contains(ticket.id),
                              onOpen: () => _open(ticket),
                            ),
                          ),
                        if (_more)
                          const LinearProgressIndicator(
                            color: AppColors.accent,
                          ),
                        if (_hasMore && !_more && !_loading)
                          TextButton(
                            onPressed: () => _load(more: true),
                            child: const Text(CustomerAccountStrings.more),
                          ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FilledButton.icon(
            onPressed: _newRequest,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.textOnAccent,
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.support_agent_rounded),
            label: const Text(CustomerAccountStrings.newRequest),
          ),
        ),
      ),
    );
  }
}
