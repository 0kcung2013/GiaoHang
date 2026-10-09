import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../constants/risk_report_strings.dart';

/// Bằng chứng và quyết định là trọng tâm; dữ liệu đối soát mở khi cần.
class SupportRiskWorkspace extends StatelessWidget {
  const SupportRiskWorkspace({
    required this.summary,
    required this.evidence,
    required this.operation,
    required this.conversation,
    required this.orderDetails,
    required this.history,
    required this.messageEvidence,
    super.key,
  });

  final Widget summary;
  final Widget evidence;
  final Widget? operation;
  final Widget? conversation;
  final Widget orderDetails;
  final Widget history;
  final Widget? messageEvidence;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final review = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          evidence,
          if (messageEvidence != null) ...[
            const SizedBox(height: AppSpacing.lg),
            messageEvidence!,
          ],
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          summary,
          const SizedBox(height: AppSpacing.lg),
          if (constraints.maxWidth >= 900 && operation != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: review),
                const SizedBox(width: AppSpacing.xl),
                SizedBox(width: 340, child: operation),
              ],
            )
          else ...[
            review,
            if (operation != null) ...[
              const SizedBox(height: AppSpacing.lg),
              operation!,
            ],
          ],
          if (conversation != null) ...[
            const SizedBox(height: AppSpacing.lg),
            conversation!,
          ],
          const SizedBox(height: AppSpacing.lg),
          SupportRiskDetailsSection(
            title: RiskReportStrings.orderAndContacts,
            icon: Icons.inventory_2_outlined,
            child: orderDetails,
          ),
          const SizedBox(height: AppSpacing.md),
          SupportRiskDetailsSection(
            title: RiskReportStrings.handlingHistory,
            icon: Icons.history_rounded,
            child: history,
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
