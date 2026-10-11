import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../core/utils/delivery_eta_calculator.dart';
import '../utils/delivery_eta_strings.dart';

class EtaAiDetailPanel extends StatefulWidget {
  const EtaAiDetailPanel({super.key, required this.eta});

  final DeliveryEtaEstimate eta;

  @override
  State<EtaAiDetailPanel> createState() => _EtaAiDetailPanelState();
}

class _EtaAiDetailPanelState extends State<EtaAiDetailPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final eta = widget.eta;
    final applied = eta.usedAiCorrection;
    final statusColor = applied ? AppColors.info : AppColors.textSecondary;

    return Semantics(
      button: true,
      label: DeliveryEtaStrings.detailsSemantics,
      hint: _expanded
          ? DeliveryEtaStrings.collapseDetails
          : DeliveryEtaStrings.expandDetails,
      child: Container(
        decoration: BoxDecoration(
          color: applied
              ? AppColors.info.withValues(alpha: 0.055)
              : AppColors.bgLight,
          borderRadius: AppRadius.lg,
          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            InkWell(
              key: const Key('eta-ai-details-toggle'),
              borderRadius: AppRadius.lg,
              onTap: () => setState(() => _expanded = !_expanded),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSpacing.xl5),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: AppRadius.sm,
                        ),
                        child: Icon(
                          applied
                              ? Icons.route_rounded
                              : Icons.schedule_rounded,
                          size: 18,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DeliveryEtaStrings.detailTitle,
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  applied
                                      ? Icons.traffic_rounded
                                      : Icons.info_rounded,
                                  size: 14,
                                  color: statusColor,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Flexible(
                                  child: Text(
                                    applied
                                        ? DeliveryEtaStrings.historicalTraffic
                                        : DeliveryEtaStrings.routeEstimate,
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: AppDuration.normal,
                        curve: AppCurve.standard,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: AppDuration.normal,
              sizeCurve: AppCurve.standard,
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: _EtaBreakdown(
                key: const Key('eta-ai-details-content'),
                eta: eta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EtaBreakdown extends StatelessWidget {
  const _EtaBreakdown({super.key, required this.eta});

  final DeliveryEtaEstimate eta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.md),
          _DetailRow(
            icon: Icons.route_rounded,
            label: DeliveryEtaStrings.travelLabel,
            value: DeliveryEtaStrings.travelMinutes(
              eta.calibratedTravelMinutes,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _DetailRow(
            icon: Icons.inventory_2_rounded,
            label: DeliveryEtaStrings.handlingLabel,
            value: DeliveryEtaStrings.handlingMinutes(eta.handlingMinutes),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: AppRadius.sm,
            ),
            child: Text(
              DeliveryEtaStrings.rangeExplanation,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.info),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
