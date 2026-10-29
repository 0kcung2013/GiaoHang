import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';

import '../../support/models/support_ticket.dart';
import '../../support/utils/support_ticket_ui.dart';
import '../../support_orders/data/support_order_repository.dart';
import '../../support_orders/dialogs/support_order_detail_dialog.dart';
import '../../support_orders/models/support_order.dart';
import '../../support_orders/utils/support_order_ui.dart';
import '../constants/customer_dossier_strings.dart';
import '../data/customer_dossier_repository.dart';
import 'customer_dossier_list.dart';

class CustomerDossierOrders extends StatelessWidget {
  const CustomerDossierOrders({
    super.key,
    required this.userId,
    required this.repository,
    required this.orderRepository,
  });
  final String userId;
  final CustomerDossierRepository repository;
  final SupportOrderRepository orderRepository;
  Future<void> _open(BuildContext context, SupportOrder order) async {
    try {
      final detail = await repository.order(order.id);
      if (!context.mounted) return;
      await showSupportOrderDetailDialog(
        context,
        order: detail,
        repository: orderRepository,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(CustomerDossierStrings.detailError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => CustomerDossierList<SupportOrder>(
    load: (offset) => repository.orders(userId, offset: offset),
    itemBuilder: (order) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(order.trackingCode, style: AppTextStyles.labelLarge),
      subtitle: Text(
        '${SupportOrderUi.statusLabel(order.status)}\n${order.pickupAddress}\n${order.deliveryAddress}',
        style: AppTextStyles.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _open(context, order),
    ),
  );
}

class CustomerDossierTickets extends StatelessWidget {
  const CustomerDossierTickets({
    super.key,
    required this.userId,
    required this.repository,
    required this.isAdmin,
  });
  final String userId;
  final CustomerDossierRepository repository;
  final bool isAdmin;
  @override
  Widget build(BuildContext context) => CustomerDossierList<SupportTicket>(
    load: (offset) => repository.tickets(userId, offset: offset),
    itemBuilder: (ticket) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        SupportTicketUi.statusIcon(ticket.status),
        color: SupportTicketUi.statusColor(ticket.status),
      ),
      title: Text(ticket.subject, style: AppTextStyles.labelLarge),
      subtitle: Text(
        '${SupportTicketUi.statusLabel(ticket.status)} · ${SupportTicketUi.dateTimeLabel(ticket.updatedAt)}',
        style: AppTextStyles.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        final router = GoRouter.of(context);
        Navigator.pop(context);
        router.push(
          (isAdmin ? '/admin-ticket/' : '/support-ticket/') + ticket.id,
        );
      },
    ),
  );
}
