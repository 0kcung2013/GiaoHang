import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../data/risk_intervention_repository.dart';

bool riskInterventionBlocksDelivery(RiskIntervention? intervention) {
  return intervention?.state == RiskInterventionState.returnRequired ||
      intervention?.state == RiskInterventionState.handoffRequired;
}

class DriverRiskInstructionRegion extends StatelessWidget {
  const DriverRiskInstructionRegion({
    required this.orderId,
    required this.repository,
    required this.builder,
    super.key,
  });

  final String orderId;
  final RiskInterventionRepository repository;
  final Widget Function(BuildContext context, bool blocksDelivery) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RiskIntervention?>(
      stream: repository.watchForOrder(orderId),
      builder: (context, snapshot) {
        final intervention = snapshot.data;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (intervention != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: DriverRiskInstructionCard(
                  intervention: intervention,
                  onConfirmCustody: () => repository.confirmCustodyResolved(
                    intervention.riskReportId,
                  ),
                ),
              ),
            builder(context, riskInterventionBlocksDelivery(intervention)),
          ],
        );
      },
    );
  }
}

class DriverRiskInstructionCard extends StatefulWidget {
  const DriverRiskInstructionCard({
    required this.intervention,
    required this.onConfirmCustody,
    super.key,
  });

  final RiskIntervention intervention;
  final Future<void> Function() onConfirmCustody;

  @override
  State<DriverRiskInstructionCard> createState() =>
      _DriverRiskInstructionCardState();
}

class _DriverRiskInstructionCardState extends State<DriverRiskInstructionCard> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.intervention.state;
    final returnRequired = state == RiskInterventionState.returnRequired;
    final handoffRequired = state == RiskInterventionState.handoffRequired;
    if (!returnRequired && !handoffRequired) {
      if (state != RiskInterventionState.awaitingTriage) {
        return const SizedBox.shrink();
      }
      return _card(
        icon: Icons.support_agent_rounded,
        title: 'CSKH đang kiểm tra báo cáo',
        body: 'Bạn vẫn có thể tiếp tục giao hàng bình thường.',
        urgent: false,
      );
    }
    return _card(
      icon: returnRequired
          ? Icons.keyboard_return_rounded
          : Icons.handshake_outlined,
      title: returnRequired
          ? 'CSKH yêu cầu hoàn trả hàng'
          : 'CSKH yêu cầu bàn giao hàng',
      body:
          widget.intervention.instruction ?? 'Liên hệ CSKH để được hướng dẫn.',
      urgent: true,
      actionLabel: returnRequired
          ? 'Đã hoàn tất hoàn trả'
          : 'Đã hoàn tất bàn giao',
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String body,
    required bool urgent,
    String? actionLabel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: urgent ? AppColors.primary : AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(
          color: urgent ? AppColors.warning : AppColors.border,
          width: urgent ? 2 : 1,
        ),
        boxShadow: AppShadow.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.warning, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.headingSmall.copyWith(
                    color: urgent
                        ? AppColors.textOnDark
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: AppTextStyles.bodySmall.copyWith(
              color: urgent ? AppColors.textOnDark : AppColors.textSecondary,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            Material(
              color: AppColors.warning,
              borderRadius: AppRadius.md,
              child: InkWell(
                onTap: _submitting ? null : _confirm,
                borderRadius: AppRadius.md,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.center,
                  child: Text(
                    _submitting ? 'Đang xác nhận…' : actionLabel,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    try {
      await widget.onConfirmCustody();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
