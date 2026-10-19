import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../constants/support_ticket_strings.dart';
import '../utils/support_ticket_ui.dart';
import 'support_request_alerts_controller.dart';
import 'support_request_alert_strings.dart';

class SupportRequestInbox extends StatelessWidget {
  const SupportRequestInbox({required this.controller, super.key});
  final SupportRequestAlertsController controller;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: 0.75,
    child: SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      SupportRequestAlertStrings.title,
                      style: AppTextStyles.headingMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: SupportRequestAlertStrings.close,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            if (controller.unreadCount > 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: controller.markAllRead,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    textStyle: AppTextStyles.labelMedium,
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Text(SupportRequestAlertStrings.markRead),
                ),
              ),
            if (controller.failed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: [
                    Text(
                      SupportRequestAlertStrings.failed,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                    TextButton(
                      onPressed: controller.reconnect,
                      child: const Text(SupportRequestAlertStrings.reconnect),
                    ),
                  ],
                ),
              ),
            if (controller.loading)
              const LinearProgressIndicator(
                color: AppColors.accent,
                semanticsLabel: SupportRequestAlertStrings.loading,
              ),
            Expanded(
              child: controller.requests.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl2),
                        child: Text(
                          controller.loading
                              ? SupportRequestAlertStrings.loading
                              : SupportRequestAlertStrings.empty,
                          style: AppTextStyles.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: controller.requests.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final ticket = controller.requests[index];
                        final unread = controller.isUnread(ticket.id);
                        return Material(
                          color: unread
                              ? AppColors.accentLight
                              : AppColors.bgCard,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(AppSpacing.lg),
                            leading: Icon(
                              ticket.isMonitoring
                                  ? Icons.radar_rounded
                                  : Icons.forum_outlined,
                              color: AppColors.accent,
                            ),
                            title: Text(
                              ticket.subject,
                              style: AppTextStyles.labelLarge,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  CaseMessageContent.decode(
                                    ticket.message,
                                  ).text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodySmall,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  '${ticket.isMonitoring ? SupportTicketStrings.monitoring : SupportTicketStrings.ticketQueue} · ${SupportTicketUi.dateTimeLabel(ticket.createdAt)}',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.pop(context, ticket.id),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
