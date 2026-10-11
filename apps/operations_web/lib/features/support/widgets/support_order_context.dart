import 'dart:async';
import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support_orders/widgets/support_order_information.dart';
import '../../support_orders/utils/support_order_information_strings.dart';
import '../dialogs/create_support_ticket_dialog.dart';
import '../data/support_ticket_repository.dart';
import '../data/support_order_context_repository.dart';

/// Shared order context for support tickets and incident investigations.
/// Conversation links stay scoped to each requester; no shared public thread.
class SupportOrderContext extends StatefulWidget {
  const SupportOrderContext({
    required this.orderId,
    this.currentTicketId,
    this.subject,
    this.repository,
    super.key,
  });
  final String orderId;
  final String? currentTicketId;
  final String? subject;
  final SupportOrderContextRepository? repository;

  @override
  State<SupportOrderContext> createState() => _SupportOrderContextState();
}

class _SupportOrderContextState extends State<SupportOrderContext> {
  late Future<SupportOrderContextData> _data = _load();
  bool _creating = false;
  StreamSubscription<void>? _changes;
  Timer? _refreshTimer;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _watchChanges();
  }

  void _watchChanges() {
    final repository =
        widget.repository ??
        SupabaseSupportOrderContextRepository(Supabase.instance.client);
    if (repository is! SupportOrderContextChangesRepository) return;
    _changes = (repository as SupportOrderContextChangesRepository)
        .watchOrder(widget.orderId)
        .listen(
          (_) => _scheduleRefresh(),
          onError: (Object error) => _scheduleRefresh(),
        );
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _scheduleRefresh(),
    );
  }

  void _scheduleRefresh() {
    if (_refreshTimer != null) return;
    _refreshTimer = Timer(const Duration(seconds: 2), () {
      _refreshTimer = null;
      if (mounted && !_creating) setState(() => _data = _load());
    });
  }

  @override
  void dispose() {
    _changes?.cancel();
    _refreshTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SupportOrderContext oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId ||
        oldWidget.repository != widget.repository) {
      _changes?.cancel();
      _pollTimer?.cancel();
      _refreshTimer?.cancel();
      _refreshTimer = null;
      _watchChanges();
      _data = _load();
    }
  }

  Future<void> _contact(SupportOrderContextData data, String party) async {
    if (_creating) return;
    final order = data.order;
    final requesterId = party == 'customer' ? order.customerId : order.driverId;
    final contact = party == 'customer' ? order.customer : order.driver;
    for (final ticket in data.tickets) {
      if (ticket.requesterId == requesterId &&
          widget.subject != null &&
          ticket.subject == widget.subject &&
          !ticket.isClosed) {
        if (ticket.id != widget.currentTicketId) {
          await context.push('/support-ticket/${ticket.id}');
        }
        return;
      }
    }
    final draft = await showCreateSupportTicketDialog(
      context,
      requesterId: requesterId,
      requesterLabel: contact?.name,
      orderId: widget.orderId,
      orderLabel: order.trackingCode,
      subject: widget.subject,
    );
    if (draft == null || !mounted) return;
    setState(() => _creating = true);
    try {
      final client = Supabase.instance.client;
      await SupabaseSupportTicketRepository(
        client,
      ).createTicket(draft, client.auth.currentUser!.id);
      if (mounted) {
        setState(() {
          _data = _load();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa tạo được trao đổi. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<SupportOrderContextData> _load() async =>
      (widget.repository ??
              SupabaseSupportOrderContextRepository(Supabase.instance.client))
          .fetch(widget.orderId);

  @override
  Widget build(BuildContext context) => FutureBuilder<SupportOrderContextData>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              SupportOrderInformationStrings.loadError,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
            _reload(),
          ],
        );
      }
      final row = snapshot.data;
      if (row == null) {
        return const LinearProgressIndicator(color: AppColors.accent);
      }
      final order = row.order;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SupportOrderInformation(
            order: order,
            onContactCustomer:
                order.customerId != null && !_creating && !row.ticketLoadFailed
                ? () => _contact(row, 'customer')
                : null,
            onContactDriver:
                order.driverId != null && !_creating && !row.ticketLoadFailed
                ? () => _contact(row, 'driver')
                : null,
          ),
          if (row.ticketLoadFailed) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              SupportOrderInformationStrings.ticketLoadError,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ],
          Align(alignment: Alignment.centerRight, child: _reload()),
          for (final ticket in row.tickets)
            if (ticket.id != widget.currentTicketId)
              TextButton.icon(
                icon: const Icon(Icons.forum_outlined),
                label: Text(
                  '${switch (ticket.requesterRole) {
                    'driver' => 'Tài xế',
                    'customer' => 'Khách hàng',
                    _ => SupportOrderInformationStrings.unknownRequester,
                  }}: ${ticket.subject}',
                ),
                onPressed: () => context.push('/support-ticket/${ticket.id}'),
              ),
        ],
      );
    },
  );

  Widget _reload() => TextButton.icon(
    onPressed: _creating
        ? null
        : () => setState(() {
            _data = _load();
          }),
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      minimumSize: const Size(48, 48),
      textStyle: AppTextStyles.labelMedium,
    ),
    icon: const Icon(Icons.refresh_rounded),
    label: const Text(SupportOrderInformationStrings.reload),
  );
}
