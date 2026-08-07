import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../core/utils/delivery_eta_calculator.dart';

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
    final statusColor = applied ? AppColors.success : AppColors.warning;

    return Semantics(
      button: true,
      label: applied
          ? 'Chi tiết ETA AI, đã áp dụng mô hình ${eta.aiDatasetLabel}'
          : 'Chi tiết ETA dự phòng, ${eta.aiFallbackReason}',
      hint: _expanded ? 'Chạm để thu gọn' : 'Chạm để xem cách tính',
      child: Container(
        decoration: BoxDecoration(
          color: applied
              ? AppColors.info.withValues(alpha: 0.055)
              : AppColors.warning.withValues(alpha: 0.07),
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
                              ? Icons.auto_awesome_rounded
                              : Icons.shield_outlined,
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
                              applied
                                  ? 'ETA có AI hiệu chỉnh'
                                  : 'ETA dự phòng an toàn',
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
                                      ? Icons.check_circle_rounded
                                      : Icons.info_rounded,
                                  size: 14,
                                  color: statusColor,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Flexible(
                                  child: Text(
                                    applied
                                        ? 'Đã áp dụng ${eta.aiDatasetLabel}'
                                        : eta.aiFallbackReason ??
                                              'Không áp dụng AI',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: statusColor,
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
    final multiplier = eta.aiTrafficMultiplier;
    final aiValue = eta.usedAiCorrection && multiplier != null
        ? '+${eta.aiAdjustmentMinutes.toStringAsFixed(1)} phút · ×${multiplier.toStringAsFixed(2)}'
        : 'Không áp dụng';

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
            icon: Icons.route_outlined,
            label: eta.usedRouteDuration
                ? 'ETA nền từ OSRM'
                : 'ETA nền khoảng cách',
            value: '${eta.baselineTravelMinutes.toStringAsFixed(1)} phút',
          ),
          const SizedBox(height: AppSpacing.sm),
          _DetailRow(
            icon: Icons.auto_awesome_rounded,
            label: 'AI giao thông lịch sử',
            value: aiValue,
            emphasized: eta.usedAiCorrection,
          ),
          const SizedBox(height: AppSpacing.sm),
          _DetailRow(
            icon: Icons.inventory_2_outlined,
            label: 'Nhận và bàn giao hàng',
            value: '+${eta.handlingMinutes} phút',
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
              eta.usedAiCorrection
                  ? '${eta.aiDatasetScope} · Model ${eta.aiModelVersion}\nKhông phải dữ liệu giao thông realtime'
                  : '${eta.aiFallbackReason}\nOSRM và quy tắc giờ cao điểm vẫn được giữ nguyên',
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
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: emphasized ? AppColors.info : AppColors.textMuted,
        ),
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
        Text(
          value,
          textAlign: TextAlign.right,
          style: AppTextStyles.labelSmall.copyWith(
            color: emphasized ? AppColors.info : AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
