import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';


class CustomerReturnStatusBanner extends StatelessWidget {
  const CustomerReturnStatusBanner({required this.mission, super.key});

  final OrderReturn mission;

  @override
  Widget build(BuildContext context) {
    final completed = mission.status == OrderReturnStatus.returned;
    final title = switch (mission.status) {
      OrderReturnStatus.approved => 'Đơn đã được duyệt hoàn trả',
      OrderReturnStatus.returning => 'Tài xế đang hoàn hàng',
      OrderReturnStatus.returned => 'Hàng đã được hoàn tất',
    };
    return Semantics(
      container: true,
      liveRegion: true,
      label: title,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: completed
              ? AppColors.success.withValues(alpha: 0.1)
              : AppColors.accentLight,
          borderRadius: AppRadius.lg,
          border: Border.all(
            color: completed ? AppColors.success : AppColors.accent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  completed
                      ? Icons.task_alt_rounded
                      : Icons.keyboard_return_rounded,
                  color: completed ? AppColors.success : AppColors.accent,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(title, style: AppTextStyles.headingSmall)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              mission.destinationAddress,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Quãng hoàn',
                    value:
                        '${(mission.routeDistanceMeters / 1000).toStringAsFixed(1)} km',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: mission.feePayer == ReturnFeePayer.customer
                        ? 'Phí khách trả'
                        : 'Phí được hỗ trợ',
                    value: formatVnd(
                      mission.feePayer == ReturnFeePayer.customer
                          ? mission.customerReturnCharge
                          : 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showDetails(context),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Xem chi tiết'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Chi tiết hoàn đơn', style: AppTextStyles.headingMedium),
              const SizedBox(height: AppSpacing.lg),
              _DetailRow(label: 'Điểm hoàn', value: mission.destinationAddress),
              _DetailRow(
                label: 'Quãng đường',
                value:
                    '${(mission.routeDistanceMeters / 1000).toStringAsFixed(1)} km',
              ),
              _DetailRow(
                label: 'Bên chịu phí',
                value: switch (mission.feePayer) {
                  ReturnFeePayer.customer => 'Khách hàng',
                  ReturnFeePayer.platform => 'GiaoHang hỗ trợ',
                  ReturnFeePayer.pendingSupport => 'CSKH đang xác minh',
                },
              ),
              _DetailRow(
                label: 'Phí hoàn khách thanh toán',
                value: formatVnd(mission.customerReturnCharge),
                emphasized: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(value, style: AppTextStyles.labelMedium),
    ],
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: emphasized
                ? AppTextStyles.headingSmall.copyWith(color: AppColors.accent)
                : AppTextStyles.bodySmall,
          ),
        ),
      ],
    ),
  );
}
