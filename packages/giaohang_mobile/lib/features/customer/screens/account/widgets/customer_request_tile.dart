import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../../order_help/utils/order_help_ui.dart';
import '../constants/customer_account_strings.dart';
import 'account_components.dart';

class CustomerRequestTile extends StatelessWidget {
  const CustomerRequestTile({
    super.key,
    required this.ticket,
    required this.onOpen,
    this.unread = false,
  });
  final SupportTicket ticket;
  final VoidCallback onOpen;
  final bool unread;
  @override
  Widget build(BuildContext context) => CustomerAccountSurface(
    child: Material(
      color: AppColors.bgCard,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    OrderHelpUi.supportStatusIcon(ticket.status),
                    color: OrderHelpUi.supportStatusColor(ticket.status),
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      OrderHelpUi.supportStatusLabel(ticket.status),
                      style: AppTextStyles.labelMedium,
                    ),
                  ),
                  if (unread)
                    const Icon(
                      Icons.mark_chat_unread_rounded,
                      color: AppColors.accent,
                      semanticLabel: CustomerAccountStrings.viewConversation,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(ticket.subject, style: AppTextStyles.headingSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                OrderHelpUi.dateTime(ticket.updatedAt),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (ticket.orderId != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    CustomerAccountStrings.relatedOrder,
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              if (ticket.resolution?.trim().isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  CustomerAccountStrings.resolution,
                  style: AppTextStyles.labelMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(ticket.resolution!, style: AppTextStyles.bodyMedium),
              ],
              const SizedBox(height: AppSpacing.sm),
              const Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
