import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support_orders/data/support_order_repository.dart';
import '../../support_orders/dialogs/support_order_detail_dialog.dart';
import '../../support_orders/models/support_order.dart';
import '../../support_orders/utils/support_order_ui.dart';
import '../dialogs/create_support_ticket_dialog.dart';
import '../data/support_ticket_repository.dart';

/// Shared order context for support tickets and incident investigations.
/// Conversation links stay scoped to each requester; no shared public thread.
class SupportOrderContext extends StatefulWidget {
  const SupportOrderContext({
    required this.orderId,
    this.currentTicketId,
    this.subject,
    super.key,
  });
  final String orderId;
  final String? currentTicketId;
  final String? subject;

  @override
  State<SupportOrderContext> createState() => _SupportOrderContextState();
}

class _SupportOrderContextState extends State<SupportOrderContext> {
  late Future<Map<String, dynamic>> _data = _load();
  bool _creating = false;

  Future<void> _contact(Map<String, dynamic> order, String party) async {
    if (_creating) return;
    for (final ticket in order['tickets'] as List) {
      if (ticket['requester_id'] == order['${party}_id'] &&
          widget.subject != null &&
          ticket['subject'] == widget.subject &&
          ticket['status'] != 'resolved' &&
          ticket['status'] != 'closed') {
        if (ticket['id'] != widget.currentTicketId) {
          await context.push('/support-ticket/${ticket['id']}');
        }
        return;
      }
    }
    final draft = await showCreateSupportTicketDialog(
      context,
      requesterId: order['${party}_id'] as String?,
      requesterLabel: order[party]?['full_name']?.toString(),
      orderId: widget.orderId,
      orderLabel: order['tracking_code']?.toString(),
      subject: widget.subject,
    );
    if (draft == null || !mounted) return;
    setState(() => _creating = true);
    try {
      final client = Supabase.instance.client;
      await SupabaseSupportTicketRepository(
        client,
      ).createTicket(draft, client.auth.currentUser!.id);
      if (mounted) setState(() => _data = _load());
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

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final order = await client
        .from('orders')
        .select(
          '*, '
          'customer:users!orders_customer_id_fkey(full_name,phone), '
          'driver:users!orders_driver_id_fkey(full_name,phone)',
        )
        .eq('id', widget.orderId)
        .single();
    final tickets = await client
        .from('support_tickets')
        .select(
          'id,requester_id,subject,status,requester:users!support_tickets_requester_id_fkey(full_name,role)',
        )
        .eq('order_id', widget.orderId)
        .order('updated_at', ascending: false);
    return {...order, 'tickets': tickets};
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return TextButton.icon(
          onPressed: () => setState(() => _data = _load()),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tải lại thông tin đơn'),
        );
      }
      final row = snapshot.data;
      if (row == null) {
        return const LinearProgressIndicator(color: AppColors.accent);
      }
      final order = SupportOrder.fromJson(row);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: AppSpacing.xl2),
          SelectableText(order.trackingCode, style: AppTextStyles.mono),
          Text(
            SupportOrderUi.statusLabel(order.status),
            style: AppTextStyles.labelMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final party in ['customer', 'driver']) ...[
            Text(
              party == 'customer' ? 'Khách hàng' : 'Tài xế',
              style: AppTextStyles.labelSmall,
            ),
            SelectableText(
              (row[party]?['full_name'] ?? 'Chưa có thông tin').toString(),
              style: AppTextStyles.bodySmall,
            ),
            if (row[party]?['phone'] != null)
              SelectableText(
                row[party]['phone'].toString(),
                style: AppTextStyles.bodySmall,
              ),
            const SizedBox(height: AppSpacing.sm),
            if (row['${party}_id'] != null)
              TextButton.icon(
                onPressed: _creating ? null : () => _contact(row, party),
                icon: const Icon(Icons.add_comment_outlined),
                label: Text(
                  party == 'customer' ? 'Liên hệ khách hàng' : 'Liên hệ tài xế',
                ),
              ),
          ],
          OutlinedButton.icon(
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Chi tiết đơn'),
            onPressed: () => showSupportOrderDetailDialog(
              context,
              order: order,
              repository: SupabaseSupportOrderRepository(
                Supabase.instance.client,
              ),
            ),
          ),
          for (final ticket in row['tickets'] as List)
            if (ticket['id'] != widget.currentTicketId)
              TextButton.icon(
                icon: const Icon(Icons.forum_outlined),
                label: Text(
                  '${ticket['requester']?['role'] == 'driver' ? 'Tài xế' : 'Khách hàng'}: ${ticket['subject']}',
                ),
                onPressed: () =>
                    context.push('/support-ticket/${ticket['id']}'),
              ),
        ],
      );
    },
  );
}
