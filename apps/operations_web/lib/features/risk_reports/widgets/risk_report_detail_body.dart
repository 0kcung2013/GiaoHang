import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart' show ReturnApprovalDraft;

import '../data/risk_report_repository.dart';
import '../dialogs/risk_journey_dialog.dart';
import '../constants/risk_journey_strings.dart';
import '../constants/risk_report_strings.dart';
import '../models/risk_message_evidence.dart';
import '../models/risk_report.dart';
import '../utils/risk_report_ui.dart';
import 'risk_attachment_section.dart';
import 'risk_badge.dart';
import 'risk_case_conversation.dart';
import 'risk_call_verification_card.dart';
import 'risk_intervention_panel.dart';
import 'risk_message_evidence_section.dart';
import 'risk_report_detail_content.dart';
import 'risk_reporter_profile_card.dart';
import 'risk_related_parties.dart';
import 'risk_case_overview.dart';
import 'support_risk_workspace.dart';
import '../../support/widgets/support_order_context.dart';
import '../../support/widgets/support_linked_tickets.dart';
import '../../support_orders/widgets/support_order_information.dart';

class RiskReportDetailBody extends StatelessWidget {
  const RiskReportDetailBody({
    required this.report,
    required this.currentUserId,
    required this.intervention,
    required this.notes,
    required this.attachments,
    required this.messageEvidence,
    required this.availableMessages,
    required this.evidenceLoading,
    required this.attachingEvidence,
    required this.onAttachEvidence,
    required this.caseMessages,
    required this.canReply,
    required this.onSendMessage,
    required this.events,
    required this.error,
    required this.onHoldBeforePickup,
    required this.onDecision,
    required this.onApproveReturn,
    required this.onConfirmCustody,
    required this.onResumeOrder,
    required this.onAddNote,
    this.showOrderContext = false,
    super.key,
  });

  final RiskReport report;
  final String currentUserId;
  final RiskIntervention? intervention;
  final List<RiskReportNote> notes;
  final List<RiskReportAttachmentView>? attachments;
  final List<RiskMessageEvidence>? messageEvidence;
  final List<RiskOrderMessage> availableMessages;
  final bool evidenceLoading;
  final bool attachingEvidence;
  final Future<void> Function(List<String>) onAttachEvidence;
  final List<CaseMessage>? caseMessages;
  final bool canReply;
  final RiskMessageSender onSendMessage;
  final List<RiskReportEvent>? events;
  final String? error;
  final Future<void> Function() onHoldBeforePickup;
  final RiskDecisionCallback onDecision;
  final Future<void> Function(ReturnApprovalDraft draft) onApproveReturn;
  final Future<void> Function() onConfirmCustody;
  final Future<void> Function() onResumeOrder;
  final Future<void> Function(String body) onAddNote;
  final bool showOrderContext;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              RiskBadge(
                label: RiskReportUi.statusLabel(report.status),
                color: RiskReportUi.statusColor(report.status),
                icon: RiskReportUi.statusIcon(report.status),
              ),
              RiskBadge(
                label: RiskReportUi.categoryLabel(report.category),
                color: AppColors.accent,
                icon: RiskReportUi.categoryIcon(report.category),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SupportRiskWorkspace(
            summary: Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                Text(
                  '${report.reporterName ?? 'Người báo cáo'} · ${switch (report.reporterRole) {
                    RiskReporterRole.driver => 'Tài xế',
                    RiskReporterRole.customer => 'Khách hàng',
                    _ => 'Hệ thống',
                  }}',
                  style: AppTextStyles.labelMedium,
                ),
                if (!report.isSystemIncident)
                  Text(
                    RiskReportUi.orderStatusLabel(report.order.status),
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.info,
                    ),
                  ),
              ],
            ),
            evidence: _EvidenceOverview(
              report: report,
              attachments: attachments,
            ),
            verification: report.isSystemIncident
                ? null
                : RiskCallVerificationCard(
                    key: ValueKey(report.id),
                    report: report,
                    enabled:
                        !report.status.isClosed &&
                        (report.assignedTo == null ||
                            report.assignedTo == currentUserId),
                  ),
            operation: intervention == null
                ? null
                : RiskInterventionPanel(
                    report: report,
                    intervention: intervention!,
                    orderStatus: report.order.status,
                    showInternalNotes: false,
                    canManage:
                        !report.status.isClosed &&
                        (report.assignedTo == null ||
                            report.assignedTo == currentUserId),
                    managementBlockedMessage: report.status.isClosed
                        ? RiskReportStrings.reportClosed
                        : 'Hồ sơ đang do ${report.assignedToName ?? 'một nhân viên khác'} phụ trách.',
                    onHoldBeforePickup: onHoldBeforePickup,
                    onDecision: onDecision,
                    onApproveReturn: onApproveReturn,
                    onConfirmCustody: onConfirmCustody,
                    onResumeOrder: onResumeOrder,
                    onAddNote: onAddNote,
                  ),
            conversation:
                report.reporterRole != RiskReporterRole.customer &&
                    report.reporterRole != RiskReporterRole.driver
                ? null
                : RiskCaseConversation(
                    publicRecipient:
                        report.reporterRole == RiskReporterRole.driver
                        ? 'tài xế'
                        : 'khách hàng',
                    allowInternal: false,
                    messages: caseMessages
                        ?.where((message) => !message.isInternal)
                        .toList(),
                    currentUserId: currentUserId,
                    canReply: canReply,
                    onSend: onSendMessage,
                  ),
            orderDetails: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RiskReporterProfileCard(report: report),
                if (!report.isSystemIncident) ...[
                  const SizedBox(height: AppSpacing.lg),
                  RiskRelatedParties(report: report),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (!report.isSystemIncident && !showOrderContext) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SupportOrderInformation(order: report.order),
                ],
                const SizedBox(height: AppSpacing.lg),
                RiskCaseOverview(report: report),
                if (showOrderContext)
                  SupportLinkedTickets(riskReportId: report.id),
                if (showOrderContext && !report.isSystemIncident)
                  SupportOrderContext(orderId: report.orderId),
              ],
            ),
            history: RiskEventTimeline(events: events),
            hasMessageEvidence: messageEvidence?.isNotEmpty ?? false,
            messageEvidence: report.isSystemIncident
                ? null
                : SupportRiskDetailsSection(
                    title:
                        'Tin nhắn bằng chứng (${messageEvidence?.length ?? 0})',
                    initiallyExpanded: messageEvidence?.isNotEmpty ?? false,
                    icon: Icons.fact_check_outlined,
                    child: RiskMessageEvidenceSection(
                      evidence: messageEvidence ?? const [],
                      availableMessages: availableMessages,
                      loading: evidenceLoading,
                      attaching: attachingEvidence,
                      onAttach: onAttachEvidence,
                    ),
                  ),
          ),
          if ((report.resolution ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            RiskResolutionBlock(text: report.resolution!),
          ],
          if (error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              error!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _EvidenceOverview extends StatelessWidget {
  const _EvidenceOverview({required this.report, required this.attachments});

  final RiskReport report;
  final List<RiskReportAttachmentView>? attachments;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            RiskReportStrings.submittedContent,
            style: AppTextStyles.labelMedium,
          ),
          if (!report.isSystemIncident && report.orderId.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => RiskJourneyDialog(report: report),
              ),
              icon: const Icon(Icons.route_rounded),
              label: const Text(RiskJourneyStrings.open),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.info,
                minimumSize: const Size(48, 48),
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            report.description,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (!report.isSystemIncident) ...[
            const SizedBox(height: AppSpacing.lg),
            RiskAttachmentSection(items: attachments),
          ],
        ],
      ),
    );
  }
}
