import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../constants/risk_report_strings.dart';

/// Bằng chứng và quyết định là trọng tâm; dữ liệu đối soát mở khi cần.
class SupportRiskWorkspace extends StatefulWidget {
  const SupportRiskWorkspace({
    required this.summary,
    required this.evidence,
    required this.operation,
    required this.conversation,
    required this.orderDetails,
    required this.history,
    required this.messageEvidence,
    this.verification,
    this.hasMessageEvidence = false,
    super.key,
  });

  final Widget summary;
  final Widget evidence;
  final Widget? operation;
  final Widget? verification;
  final Widget? conversation;
  final Widget orderDetails;
  final Widget history;
  final Widget? messageEvidence;
  final bool hasMessageEvidence;

  @override
  State<SupportRiskWorkspace> createState() => _SupportRiskWorkspaceState();
}

class _SupportRiskWorkspaceState extends State<SupportRiskWorkspace> {
  bool _showConversation = false;
  final _conversationKey = GlobalKey();
  final _verificationKey = GlobalKey();

  void _select(bool conversation) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _showConversation = conversation);
  }

  Widget _tab(String label, bool conversation) => Semantics(
    selected: _showConversation == conversation,
    child: TextButton(
      onPressed: () => _select(conversation),
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: _showConversation == conversation
            ? AppColors.accent
            : AppColors.textSecondary,
        backgroundColor: _showConversation == conversation
            ? AppColors.accentLight
            : Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        textStyle: AppTextStyles.labelMedium,
      ),
      child: Text(label),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final review = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Visibility(
            visible: !_showConversation,
            maintainState: true,
            child: widget.evidence,
          ),
          if (widget.hasMessageEvidence &&
              widget.messageEvidence != null &&
              !_showConversation) ...[
            const SizedBox(height: AppSpacing.lg),
            widget.messageEvidence!,
          ],
          if (widget.conversation != null)
            Visibility(
              key: _conversationKey,
              visible: _showConversation,
              maintainState: true,
              child: widget.conversation!,
            ),
        ],
      );
      final actions = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.verification != null)
            KeyedSubtree(key: _verificationKey, child: widget.verification!),
          if (widget.verification != null && widget.operation != null)
            const SizedBox(height: AppSpacing.lg),
          if (widget.operation != null) widget.operation!,
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          widget.summary,
          const SizedBox(height: AppSpacing.lg),
          if (widget.conversation != null) ...[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _tab(RiskReportStrings.reportTab, false),
                _tab(RiskReportStrings.conversationTab, true),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (constraints.maxWidth >= 900 &&
              (widget.operation != null || widget.verification != null))
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: review),
                const SizedBox(width: AppSpacing.xl),
                SizedBox(width: 320, child: actions),
              ],
            )
          else ...[
            review,
            if (widget.operation != null || widget.verification != null) ...[
              const SizedBox(height: AppSpacing.lg),
              actions,
            ],
          ],
          const SizedBox(height: AppSpacing.lg),
          SupportRiskDetailsSection(
            title: RiskReportStrings.orderAndContacts,
            icon: Icons.inventory_2_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                widget.orderDetails,
                if (!widget.hasMessageEvidence &&
                    widget.messageEvidence != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  widget.messageEvidence!,
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SupportRiskDetailsSection(
            title: RiskReportStrings.handlingHistory,
            icon: Icons.history_rounded,
            child: widget.history,
          ),
        ],
      );
    },
  );
}

class SupportRiskDetailsSection extends StatelessWidget {
  const SupportRiskDetailsSection({
    required this.title,
    required this.icon,
    required this.child,
    this.initiallyExpanded = false,
    super.key,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: AppRadius.lg,
      border: Border.all(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: AppColors.accent,
      collapsedIconColor: AppColors.textSecondary,
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: AppTextStyles.labelMedium),
      childrenPadding: const EdgeInsets.all(AppSpacing.lg),
      children: [child],
    ),
  );
}
