import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../order_help/data/customer_support_ticket_repository.dart';
import '../../../../order_help/models/order_help_option.dart';
import '../../../../order_help/widgets/support_chat/support_chat_sheet.dart';

Future<void> showDriverSupportFlow(
  BuildContext context, {
  required OrderModel order,
  ParticipantSupportTicketRepository? repository,
}) async {
  final requesterId = order.driverId;
  if (requesterId == null) return;

  final supportRepository =
      repository ?? SupabaseParticipantSupportTicketRepository();
  SupportTicket? active;
  try {
    final tickets = await supportRepository.fetchForOrder(order.id);
    active = tickets.cast<SupportTicket?>().firstWhere(
      (ticket) =>
          ticket != null &&
          !ticket.status.isClosed &&
          ticket.subject == driverOrderSupportOption.label,
      orElse: () => null,
    );
  } catch (_) {
    // Vẫn mở chat mới khi bước tìm cuộc trò chuyện cũ tạm thời thất bại.
  }
  if (!context.mounted) return;

  await showParticipantSupportChatSheet(
    context,
    requesterId: requesterId,
    requesterRole: 'driver',
    orderId: order.id,
    orderCode: order.trackingCode,
    subject: driverOrderSupportOption.label,
    priority: driverOrderSupportOption.priority,
    repository: supportRepository,
    initialTicket: active,
  );
}

class DriverSupportAction extends StatefulWidget {
  const DriverSupportAction({
    required this.order,
    this.dark = false,
    this.repository,
    super.key,
  });

  final OrderModel order;
  final bool dark;
  final ParticipantSupportTicketRepository? repository;

  @override
  State<DriverSupportAction> createState() => _DriverSupportActionState();
}

class _DriverSupportActionState extends State<DriverSupportAction> {
  bool _opening = false;

  Future<void> _openSupport() async {
    if (_opening || widget.order.driverId == null) return;
    setState(() => _opening = true);
    try {
      await showDriverSupportFlow(
        context,
        order: widget.order,
        repository: widget.repository,
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.dark
        ? AppColors.textOnDark
        : AppColors.textPrimary;
    final background = widget.dark ? AppColors.bgDarkCard : AppColors.bgCard;
    return Semantics(
      button: true,
      enabled: !_opening && widget.order.driverId != null,
      label: driverOrderSupportOption.label,
      child: Material(
        color: background,
        borderRadius: AppRadius.md,
        child: InkWell(
          key: const Key('driver-support-action'),
          onTap: _opening ? null : _openSupport,
          borderRadius: AppRadius.md,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: AppRadius.md,
              border: Border.all(
                color: widget.dark ? AppColors.info : AppColors.border,
              ),
              boxShadow: widget.dark ? AppShadow.elevated : AppShadow.subtle,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _opening
                      ? Icons.hourglass_top_rounded
                      : Icons.support_agent_rounded,
                  color: AppColors.info,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    _opening ? 'Đang mở...' : driverOrderSupportOption.label,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
