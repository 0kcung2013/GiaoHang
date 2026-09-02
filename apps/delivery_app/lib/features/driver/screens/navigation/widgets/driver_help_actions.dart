import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../order_help/data/customer_support_ticket_repository.dart';
import '../../../../risk_reports/widgets/risk_report_sheet.dart';
import 'driver_risk_action.dart';
import 'driver_support_action.dart';

class DriverHelpActions extends StatelessWidget {
  const DriverHelpActions({
    required this.order,
    this.initialLatitude,
    this.initialLongitude,
    this.dark = false,
    this.collapsed = false,
    this.supportRepository,
    super.key,
  });

  final OrderModel order;
  final double? initialLatitude;
  final double? initialLongitude;
  final bool dark;
  final bool collapsed;
  final ParticipantSupportTicketRepository? supportRepository;

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return _CollapsedDriverHelpActions(
        order: order,
        initialLatitude: initialLatitude,
        initialLongitude: initialLongitude,
        supportRepository: supportRepository,
      );
    }

    return Wrap(
      alignment: WrapAlignment.end,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        DriverSupportAction(
          order: order,
          dark: dark,
          repository: supportRepository,
        ),
        DriverRiskAction(
          order: order,
          initialLatitude: initialLatitude,
          initialLongitude: initialLongitude,
          dark: dark,
        ),
      ],
    );
  }
}

enum _DriverHelpChoice { support, risk }

class _CollapsedDriverHelpActions extends StatelessWidget {
  const _CollapsedDriverHelpActions({
    required this.order,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.supportRepository,
  });

  final OrderModel order;
  final double? initialLatitude;
  final double? initialLongitude;
  final ParticipantSupportTicketRepository? supportRepository;

  Future<void> _openActions(BuildContext context) async {
    final choice = await showModalBottomSheet<_DriverHelpChoice>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl2),
      builder: (sheetContext) => _DriverHelpActionSheet(
        canContactSupport: order.driverId != null,
        canReportRisk:
            order.status != 'delivered' && order.status != 'returned',
      ),
    );
    if (choice == null || !context.mounted) return;

    switch (choice) {
      case _DriverHelpChoice.support:
        await showDriverSupportFlow(
          context,
          order: order,
          repository: supportRepository,
        );
        break;
      case _DriverHelpChoice.risk:
        await showRiskReportSheet(
          context,
          order: order,
          role: RiskReporterRole.driver,
          initialLatitude: initialLatitude,
          initialLongitude: initialLongitude,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Hỗ trợ và báo cáo sự cố',
      child: Material(
        color: AppColors.bgCard,
        borderRadius: AppRadius.full,
        elevation: 3,
        shadowColor: AppColors.primary.withValues(alpha: 0.2),
        child: IconButton(
          key: const Key('driver-help-menu-button'),
          onPressed: () => _openActions(context),
          tooltip: 'Hỗ trợ và sự cố',
          icon: const Icon(
            Icons.headset_mic_rounded,
            color: AppColors.info,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _DriverHelpActionSheet extends StatelessWidget {
  const _DriverHelpActionSheet({
    required this.canContactSupport,
    required this.canReportRisk,
  });

  final bool canContactSupport;
  final bool canReportRisk;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.sm,
          AppSpacing.screenH,
          AppSpacing.xl2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: AppSpacing.xl4,
                height: AppSpacing.xs,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: AppRadius.full,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Hỗ trợ chuyến đi', style: AppTextStyles.headingMedium),
            const SizedBox(height: AppSpacing.md),
            _DriverHelpActionTile(
              key: const Key('driver-help-support-option'),
              icon: Icons.support_agent_rounded,
              iconColor: AppColors.info,
              title: 'Trao đổi với CSKH',
              subtitle: 'Hỏi về đơn hoặc xử lý phát sinh',
              onTap: canContactSupport
                  ? () => Navigator.pop(context, _DriverHelpChoice.support)
                  : null,
            ),
            if (canReportRisk) ...[
              const SizedBox(height: AppSpacing.sm),
              _DriverHelpActionTile(
                key: const Key('driver-help-risk-option'),
                icon: Icons.report_problem_outlined,
                iconColor: AppColors.warning,
                title: 'Báo cáo sự cố',
                subtitle: 'An toàn, hàng hóa hoặc người nhận',
                onTap: () => Navigator.pop(context, _DriverHelpChoice.risk),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DriverHelpActionTile extends StatelessWidget {
  const _DriverHelpActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgLight,
      borderRadius: AppRadius.lg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lg,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.lg,
          ),
          child: Row(
            children: [
              Container(
                width: AppSpacing.xl5,
                height: AppSpacing.xl5,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.md,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
