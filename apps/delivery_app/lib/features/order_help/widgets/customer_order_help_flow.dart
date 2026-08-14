import 'package:flutter/material.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../core/models/order_model.dart';
import '../../risk_reports/data/participant_risk_report_query_repository.dart';
import '../../risk_reports/data/risk_report_repository.dart';
import '../../risk_reports/widgets/risk_report_sheet.dart';
import '../data/customer_support_ticket_repository.dart';
import '../models/order_help_option.dart';
import '../models/order_help_receipt.dart';
import 'customer_support_request_sheet.dart';
import 'order_help_category_sheet.dart';
import 'order_help_receipt_sheet.dart';

Future<bool> showCustomerOrderHelpFlow(
  BuildContext context, {
  required OrderModel order,
  CustomerSupportTicketRepository? supportRepository,
  ParticipantRiskReportRepository? riskCommandRepository,
  ParticipantRiskReportQueryRepository? riskQueryRepository,
}) async {
  final option = await showOrderHelpCategorySheet(context);
  if (option == null || !context.mounted) return false;

  final support =
      supportRepository ?? SupabaseCustomerSupportTicketRepository();
  final riskQuery =
      riskQueryRepository ?? SupabaseParticipantRiskReportQueryRepository();
  OrderHelpReceipt? receipt;

  if (option.channel == OrderHelpChannel.support) {
    final existing = await _findExistingSupport(
      support,
      order.id,
      option.label,
    );
    if (!context.mounted) return false;
    if (existing != null) {
      receipt = OrderHelpReceipt(
        id: existing.id,
        type: OrderHelpRecordType.supportTicket,
        supportStatus: existing.status,
        created: false,
      );
    } else {
      final ticket = await showCustomerSupportRequestSheet(
        context,
        order: order,
        option: option,
        repository: support,
      );
      if (ticket != null) {
        receipt = OrderHelpReceipt(
          id: ticket.id,
          type: OrderHelpRecordType.supportTicket,
          supportStatus: ticket.status,
          created: true,
        );
      }
    }
  } else {
    final existing = await riskQuery.findActive(order.id, option.category);
    if (!context.mounted) return false;
    if (existing != null) {
      receipt = OrderHelpReceipt(
        id: existing.id,
        type: OrderHelpRecordType.riskReport,
        riskStatus: existing.status,
        created: false,
      );
    } else {
      final result = await showRiskReportSheet(
        context,
        order: order,
        role: RiskReporterRole.customer,
        initialCategory: option.category,
        repository:
            riskCommandRepository ?? SupabaseParticipantRiskReportRepository(),
      );
      if (result != null) {
        receipt = OrderHelpReceipt(
          id: result.reportId,
          type: OrderHelpRecordType.riskReport,
          riskStatus: result.status,
          created: true,
        );
      }
    }
  }

  if (receipt == null || !context.mounted) return false;
  await showOrderHelpReceiptSheet(context, receipt);
  return true;
}

Future<SupportTicket?> _findExistingSupport(
  CustomerSupportTicketRepository repository,
  String orderId,
  String subject,
) async {
  try {
    final tickets = await repository.fetchForOrder(orderId);
    for (final ticket in tickets) {
      if (!ticket.status.isClosed && ticket.subject == subject) return ticket;
    }
  } catch (_) {
    // Không chặn người dùng tạo yêu cầu nếu bước dò trùng tạm thời thất bại.
  }
  return null;
}
