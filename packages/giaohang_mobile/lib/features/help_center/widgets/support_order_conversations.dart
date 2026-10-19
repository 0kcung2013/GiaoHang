import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../core/models/order_model.dart';
import '../../order_help/data/customer_support_ticket_repository.dart';
import '../../order_help/utils/order_help_ui.dart';
import '../../order_help/widgets/support_chat/support_chat_sheet.dart';
import '../help_center_strings.dart';

/// Keep the requester's existing cases visible, including closed conversations.
/// A failed read propagates to the picker instead of silently creating a duplicate.
Future<void> openHelpOrderChat(
  BuildContext context, {
  required OrderModel order,
  required String requesterId,
  required String requesterRole,
  required ParticipantSupportTicketRepository repository,
  VoidCallback? onLoaded,
}) async {
  final all = await repository.fetchForOrder(order.id);
  if (!context.mounted) return;
  onLoaded?.call();
  final tickets =
      all
          .where(
            (ticket) =>
                ticket.requesterId == requesterId && !ticket.isMonitoring,
          )
          .toList()
        ..sort((left, right) {
          if (left.status.isClosed != right.status.isClosed) {
            return left.status.isClosed ? 1 : -1;
          }
          return right.updatedAt.compareTo(left.updatedAt);
        });
  SupportTicket? existing;
  if (tickets.isNotEmpty) {
    final choice = await showModalBottomSheet<({SupportTicket? ticket})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _Conversations(order: order, tickets: tickets),
    );
    if (choice == null || !context.mounted) return;
    existing = choice.ticket;
  }
  if (!context.mounted) return;
  await showParticipantSupportChatSheet(
    context,
    requesterId: requesterId,
    requesterRole: requesterRole,
    orderId: order.id,
    orderCode: order.trackingCode,
    subject: existing?.subject ?? HelpCenterStrings.subject,
    priority: existing?.priority ?? SupportTicketPriority.normal,
    repository: repository,
    initialTicket: existing,
  );
}

class _Conversations extends StatelessWidget {
  const _Conversations({required this.order, required this.tickets});
  final OrderModel order;
  final List<SupportTicket> tickets;

  @override
  Widget build(BuildContext context) {
    final activeGeneral = tickets
        .where(
          (ticket) =>
              !ticket.status.isClosed &&
              ticket.subject == HelpCenterStrings.subject,
        )
        .firstOrNull;
    return FractionallySizedBox(
      heightFactor: 0.75,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          HelpCenterStrings.conversations,
                          style: AppTextStyles.headingMedium,
                        ),
                        Text(order.trackingCode, style: AppTextStyles.mono),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: HelpCenterStrings.close,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: tickets.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppColors.border),
                itemBuilder: (context, index) {
                  final ticket = tickets[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    leading: Icon(
                      OrderHelpUi.supportStatusIcon(ticket.status),
                      color: AppColors.accent,
                    ),
                    title: Text(
                      ticket.subject,
                      style: AppTextStyles.labelLarge,
                    ),
                    subtitle: Text(
                      '${OrderHelpUi.supportStatusLabel(ticket.status)} · ${OrderHelpUi.dateTime(ticket.updatedAt)}',
                      style: AppTextStyles.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.pop(context, (ticket: ticket)),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, (ticket: activeGeneral)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 52),
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.textOnAccent,
                    textStyle: AppTextStyles.labelLarge,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.md,
                    ),
                  ),
                  icon: Icon(
                    activeGeneral == null
                        ? Icons.add_rounded
                        : Icons.forum_rounded,
                  ),
                  label: Text(
                    activeGeneral == null
                        ? HelpCenterStrings.newConversation
                        : HelpCenterStrings.chat,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
