import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/risk_report.dart';
import '../utils/risk_report_ui.dart';

class RiskReportDetailHeader extends StatelessWidget {
  const RiskReportDetailHeader({
    required this.report,
    required this.onClose,
    super.key,
  });

  final RiskReport report;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: AppRadius.md,
            ),
            child: const Icon(
              Icons.gpp_maybe_outlined,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headingMedium,
                ),
                Text(
                  '${report.isSystemIncident ? 'Sự cố hệ thống' : report.order.trackingCode} · '
                  '${RiskReportUi.formatDateTime(report.createdAt)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Đóng',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class RiskOrderRoute extends StatelessWidget {
  const RiskOrderRoute({required this.report, super.key});
  final RiskReport report;

  @override
  Widget build(BuildContext context) {
    if (report.isSystemIncident) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: AppRadius.lg,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.dns_outlined, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Phạm vi toàn hệ thống',
                    style: AppTextStyles.labelMedium,
                  ),
                  Text(
                    report.component?.trim().isNotEmpty == true
                        ? 'Thành phần: ${report.component}'
                        : 'Chưa xác định thành phần bị ảnh hưởng',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _RouteLine(
            icon: Icons.radio_button_checked_rounded,
            color: AppColors.markerPickup,
            text: report.order.pickupAddress,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 9),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                height: 16,
                child: VerticalDivider(color: AppColors.border, width: 1),
              ),
            ),
          ),
          _RouteLine(
            icon: Icons.location_on_rounded,
            color: AppColors.markerDrop,
            text: report.order.deliveryAddress,
          ),
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.icon,
    required this.color,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class RiskEventTimeline extends StatelessWidget {
  const RiskEventTimeline({required this.events, super.key});
  final List<RiskReportEvent>? events;

  @override
  Widget build(BuildContext context) {
    if (events == null) return const _TimelineLoading();
    return Column(
      children: events!
          .map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: AppColors.bgLight,
                      borderRadius: AppRadius.full,
                    ),
                    child: Icon(
                      RiskReportUi.statusIcon(event.toStatus),
                      size: 18,
                      color: RiskReportUi.statusColor(event.toStatus),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          RiskReportUi.eventLabel(event.eventType),
                          style: AppTextStyles.labelMedium,
                        ),
                        Text(
                          RiskReportUi.formatDateTime(event.createdAt),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        if ((event.note ?? '').isNotEmpty)
                          Text(event.note!, style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class RiskResolutionBlock extends StatelessWidget {
  const RiskResolutionBlock({required this.text, super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.07),
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Text('Kết luận: $text', style: AppTextStyles.bodySmall),
    );
  }
}

class CriticalRiskNotice extends StatelessWidget {
  const CriticalRiskNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.07),
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Báo cáo nghiêm trọng cần Admin đưa ra kết luận cuối.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineLoading extends StatelessWidget {
  const _TimelineLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _TimelinePlaceholder(width: 220),
        SizedBox(height: AppSpacing.md),
        _TimelinePlaceholder(width: 170),
      ],
    );
  }
}

class _TimelinePlaceholder extends StatelessWidget {
  const _TimelinePlaceholder({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: width,
        height: 18,
        decoration: const BoxDecoration(
          color: AppColors.border,
          borderRadius: AppRadius.sm,
        ),
      ),
    );
  }
}
