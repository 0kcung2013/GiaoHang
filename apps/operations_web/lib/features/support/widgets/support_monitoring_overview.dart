import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../constants/support_monitoring_strings.dart';
import '../models/support_ticket.dart';

/// Shows the operational outcome before the raw system event details.
class SupportMonitoringOverview extends StatelessWidget {
  const SupportMonitoringOverview({
    required this.ticket,
    this.automatic,
    this.messages,
    super.key,
  });
  final SupportTicket ticket;
  final bool? automatic;
  final List<CaseMessage>? messages;

  @override
  Widget build(BuildContext context) {
    final isAutomatic = automatic ?? ticket.isAutomaticMonitoringNotice;
    final custody =
        ticket.subject.contains('mất GPS khi đang giữ hàng') ||
        ticket.subject.contains('cần xác minh hành trình') ||
        (ticket.lastMessageBody ?? ticket.message).contains(
          'CSKH cần liên hệ xác minh',
        ) ||
        (messages?.any(
              (item) =>
                  item.isSystem &&
                  item.body.contains('CSKH cần liên hệ xác minh'),
            ) ??
            false);
    final color = isAutomatic ? AppColors.info : AppColors.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.2))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isAutomatic ? Icons.history_rounded : Icons.support_agent_rounded,
            color: color,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAutomatic
                      ? SupportMonitoringStrings.automaticStatus
                      : custody
                      ? SupportMonitoringStrings.verify
                      : SupportMonitoringStrings.participantRequest,
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isAutomatic
                      ? SupportMonitoringStrings.automaticSummary
                      : custody
                      ? SupportMonitoringStrings.verifySummary
                      : SupportMonitoringStrings.participantHelp,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  isAutomatic
                      ? SupportMonitoringStrings.automaticHelp
                      : custody
                      ? SupportMonitoringStrings.verifyHelp
                      : SupportMonitoringStrings.queueHint,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SupportAutomaticMonitoringLog extends StatelessWidget {
  const SupportAutomaticMonitoringLog({
    required this.ticket,
    this.messages,
    super.key,
  });
  final SupportTicket ticket;
  final List<CaseMessage>? messages;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.bgLight,
    child: ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        SupportMonitoringOverview(ticket: ticket, automatic: true),
        const SizedBox(height: AppSpacing.lg),
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          title: Text(
            SupportMonitoringStrings.eventDetails,
            style: AppTextStyles.labelMedium,
          ),
          childrenPadding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            for (final body in {
              ticket.message,
              ...?messages?.map((item) => item.body),
            })
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    CaseMessageContent.decode(body).text,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
