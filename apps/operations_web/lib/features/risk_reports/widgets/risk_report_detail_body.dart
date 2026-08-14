import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../data/risk_report_repository.dart';
import '../models/risk_message_evidence.dart';
import '../models/risk_report.dart';
import '../utils/risk_report_ui.dart';
import 'risk_attachment_section.dart';
import 'risk_badge.dart';
import 'risk_case_conversation.dart';
import 'risk_intervention_panel.dart';
import 'risk_message_evidence_section.dart';
import 'risk_report_detail_content.dart';

class RiskReportDetailBody extends StatelessWidget {
  const RiskReportDetailBody({
    required this.report,
    required this.currentUserId,
    required this.criticalRestricted,
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
    required this.onConfirmCustody,
    required this.onResumeOrder,
    required this.onAddNote,
    super.key,
  });

  final RiskReport report;
  final String currentUserId;
  final bool criticalRestricted;
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
  final Future<void> Function() onConfirmCustody;
  final Future<void> Function() onResumeOrder;
  final Future<void> Function(String body) onAddNote;

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
                label: RiskReportUi.severityLabel(report.severity),
                color: RiskReportUi.severityColor(report.severity),
                icon: RiskReportUi.severityIcon(report.severity),
              ),
              RiskBadge(
                label: RiskReportUi.statusLabel(report.status),
                color: RiskReportUi.statusColor(report.status),
                icon: RiskReportUi.statusIcon(report.status),
              ),
              RiskBadge(
                label: RiskReportUi.categoryLabel(report.category),
                color: AppColors.primary,
                icon: RiskReportUi.categoryIcon(report.category),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          RiskOrderRoute(report: report),
          if (intervention != null) ...[
            const SizedBox(height: AppSpacing.xl),
            RiskInterventionPanel(
              report: report,
              intervention: intervention!,
              orderStatus: report.order.status,
              canManage: report.assignedTo == currentUserId,
              managementBlockedMessage: report.assignedTo == null
                  ? 'Nhận và bắt đầu xác minh trước khi can thiệp đơn.'
                  : 'Hồ sơ đang do ${report.assignedToName ?? 'một nhân viên khác'} phụ trách.',
              notes: notes,
              onHoldBeforePickup: onHoldBeforePickup,
              onDecision: onDecision,
              onConfirmCustody: onConfirmCustody,
              onResumeOrder: onResumeOrder,
              onAddNote: onAddNote,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text('Dấu hiệu và bằng chứng', style: AppTextStyles.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            report.description,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (!report.isSystemIncident) ...[
            const SizedBox(height: AppSpacing.xl),
            RiskAttachmentSection(items: attachments),
            const SizedBox(height: AppSpacing.xl),
            RiskMessageEvidenceSection(
              evidence: messageEvidence ?? const [],
              availableMessages: availableMessages,
              loading: evidenceLoading,
              attaching: attachingEvidence,
              onAttach: onAttachEvidence,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          RiskCaseConversation(
            messages: caseMessages,
            currentUserId: currentUserId,
            canReply: canReply,
            onSend: onSendMessage,
          ),
          if ((report.resolution ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            RiskResolutionBlock(text: report.resolution!),
          ],
          if (criticalRestricted) ...[
            const SizedBox(height: AppSpacing.xl),
            const CriticalRiskNotice(),
          ],
          if (error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              error!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.xl2),
          Row(
            children: [
              Text('Lịch sử xử lý', style: AppTextStyles.headingSmall),
              const Spacer(),
              Text(
                '${events?.length ?? 0} sự kiện',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          RiskEventTimeline(events: events),
        ],
      ),
    );
  }
}
