import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart' show ReturnApprovalDraft;

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
import 'risk_reporter_profile_card.dart';

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
    required this.onApproveReturn,
    required this.onConfirmCustody,
    required this.onResumeOrder,
    required this.onAddNote,
    this.showSeverity = false,
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
  final Future<void> Function(ReturnApprovalDraft draft) onApproveReturn;
  final Future<void> Function() onConfirmCustody;
  final Future<void> Function() onResumeOrder;
  final Future<void> Function(String body) onAddNote;
  final bool showSeverity;

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
              if (showSeverity)
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
          _VerificationOverview(
            report: report,
            currentUserId: currentUserId,
            intervention: intervention,
            notes: notes,
            attachments: attachments,
            onHoldBeforePickup: onHoldBeforePickup,
            onDecision: onDecision,
            onApproveReturn: onApproveReturn,
            onConfirmCustody: onConfirmCustody,
            onResumeOrder: onResumeOrder,
            onAddNote: onAddNote,
          ),
          if (!report.isSystemIncident) ...[
            const SizedBox(height: AppSpacing.xl2),
            RiskMessageEvidenceSection(
              evidence: messageEvidence ?? const [],
              availableMessages: availableMessages,
              loading: evidenceLoading,
              attaching: attachingEvidence,
              onAttach: onAttachEvidence,
            ),
          ],
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
          const SizedBox(height: AppSpacing.xl),
          _AdditionalCaseDetails(
            messages: caseMessages,
            currentUserId: currentUserId,
            canReply: canReply,
            onSendMessage: onSendMessage,
            events: events,
          ),
        ],
      ),
    );
  }
}

class _VerificationOverview extends StatelessWidget {
  const _VerificationOverview({
    required this.report,
    required this.currentUserId,
    required this.intervention,
    required this.notes,
    required this.attachments,
    required this.onHoldBeforePickup,
    required this.onDecision,
    required this.onApproveReturn,
    required this.onConfirmCustody,
    required this.onResumeOrder,
    required this.onAddNote,
  });

  final RiskReport report;
  final String currentUserId;
  final RiskIntervention? intervention;
  final List<RiskReportNote> notes;
  final List<RiskReportAttachmentView>? attachments;
  final Future<void> Function() onHoldBeforePickup;
  final RiskDecisionCallback onDecision;
  final Future<void> Function(ReturnApprovalDraft draft) onApproveReturn;
  final Future<void> Function() onConfirmCustody;
  final Future<void> Function() onResumeOrder;
  final Future<void> Function(String body) onAddNote;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final evidence = _EvidenceOverview(
          report: report,
          attachments: attachments,
        );
        final contextPanel = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RiskReporterProfileCard(report: report),
            const SizedBox(height: AppSpacing.lg),
            RiskOrderRoute(report: report),
            if (intervention != null) ...[
              const SizedBox(height: AppSpacing.lg),
              RiskInterventionPanel(
                report: report,
                intervention: intervention!,
                orderStatus: report.order.status,
                canManage:
                    report.assignedTo == null ||
                    report.assignedTo == currentUserId,
                canAddNote: report.assignedTo == currentUserId,
                managementBlockedMessage:
                    'Hồ sơ đang do ${report.assignedToName ?? 'một nhân viên khác'} phụ trách.',
                notes: notes,
                onHoldBeforePickup: onHoldBeforePickup,
                onDecision: onDecision,
                onApproveReturn: onApproveReturn,
                onConfirmCustody: onConfirmCustody,
                onResumeOrder: onResumeOrder,
                onAddNote: onAddNote,
              ),
            ],
          ],
        );

        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              contextPanel,
              const SizedBox(height: AppSpacing.xl),
              evidence,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: evidence),
            const SizedBox(width: AppSpacing.xl),
            SizedBox(width: 340, child: contextPanel),
          ],
        );
      },
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
          Text('Nội dung người dùng gửi', style: AppTextStyles.labelMedium),
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

class _AdditionalCaseDetails extends StatelessWidget {
  const _AdditionalCaseDetails({
    required this.messages,
    required this.currentUserId,
    required this.canReply,
    required this.onSendMessage,
    required this.events,
  });

  final List<CaseMessage>? messages;
  final String currentUserId;
  final bool canReply;
  final RiskMessageSender onSendMessage;
  final List<RiskReportEvent>? events;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const Key('risk-additional-case-details'),
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.textMuted,
        title: Text('Trao đổi và lịch sử', style: AppTextStyles.labelMedium),
        subtitle: Text(
          '${messages?.length ?? 0} trao đổi · ${events?.length ?? 0} sự kiện',
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
        ),
        children: [
          RiskCaseConversation(
            messages: messages,
            currentUserId: currentUserId,
            canReply: canReply,
            onSend: onSendMessage,
          ),
          const SizedBox(height: AppSpacing.xl),
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
