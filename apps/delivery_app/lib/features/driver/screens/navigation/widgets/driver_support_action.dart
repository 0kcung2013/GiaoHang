import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../order_help/data/customer_support_ticket_repository.dart';
import '../../../../order_help/models/order_help_option.dart';
import '../../../../order_help/widgets/customer_support_request_sheet.dart';
import '../../../../order_help/widgets/order_help_progress_sheet.dart';

Future<void> showDriverSupportFlow(
  BuildContext context, {
  required OrderModel order,
  ParticipantSupportTicketRepository? repository,
}) async {
  final requesterId = order.driverId;
  if (requesterId == null) return;

  final supportRepository =
      repository ?? SupabaseParticipantSupportTicketRepository();
  final tickets = await supportRepository.fetchForOrder(order.id);
  final active = tickets.cast<SupportTicket?>().firstWhere(
    (ticket) =>
        ticket != null &&
        !ticket.status.isClosed &&
        ticket.subject == driverOrderSupportOption.label,
    orElse: () => null,
  );
  if (!context.mounted) return;

  if (active != null) {
    await showSupportTicketProgressSheet(context, active, supportRepository);
    return;
  }

  final ticket = await showParticipantSupportRequestSheet(
    context,
    requesterId: requesterId,
    order: order,
    option: driverOrderSupportOption,
    repository: supportRepository,
  );
  if (ticket != null && context.mounted) {
    await showSupportTicketProgressSheet(context, ticket, supportRepository);
  }
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
