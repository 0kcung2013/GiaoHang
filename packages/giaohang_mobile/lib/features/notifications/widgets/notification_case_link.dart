import 'package:flutter/material.dart';

import '../../../core/models/notification_model.dart';
import '../../order_help/data/customer_support_ticket_repository.dart';
import '../../order_help/widgets/order_help_progress_sheet.dart';
import '../../risk_reports/data/participant_risk_report_query_repository.dart';

Future<void> openNotificationCase(
  BuildContext context,
  NotificationModel notification,
) async {
  try {
    if (notification.supportTicketId != null) {
      final repository = SupabaseParticipantSupportTicketRepository();
      final ticket = await repository.fetchById(notification.supportTicketId!);
      if (context.mounted) {
        await showSupportTicketProgressSheet(context, ticket, repository);
      }
    } else if (notification.riskReportId != null) {
      final repository = SupabaseParticipantRiskReportQueryRepository();
      final report = await repository.fetchById(notification.riskReportId!);
      if (context.mounted) {
        await showRiskReportProgressSheet(context, report, repository);
      }
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được hồ sơ. Vui lòng thử lại.')),
      );
    }
  }
}
