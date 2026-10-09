import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../widgets/driver_swipe_action.dart';

/// Presentation only. Arrival and elapsed time must come from the server.
/// A null arrival callback leaves the swipe disabled until integration is ready.
class DriverDeliveryWaitCard extends StatelessWidget {
  const DriverDeliveryWaitCard({
    super.key,
    required this.isNearDelivery,
    this.confirmedWait,
    this.isLoading = false,
    this.onConfirmArrival,
    this.onReportRecipient,
  });

  final bool isNearDelivery;
  final Duration? confirmedWait;
  final bool isLoading;
  final VoidCallback? onConfirmArrival;
  final VoidCallback? onReportRecipient;

  static const minimumWait = Duration(minutes: 10);

  @override
  Widget build(BuildContext context) {
    final wait = confirmedWait;
    final ready = wait != null && wait >= minimumWait;
    final remaining = wait == null ? minimumWait : minimumWait - wait;
    final seconds = remaining.inSeconds.clamp(0, 600);
    final countdown =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                wait == null
                    ? Icons.location_on_rounded
                    : Icons.check_circle_rounded,
                color: AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  wait == null ? 'Đến điểm giao hàng' : 'Đã đến nơi giao hàng',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (wait == null) ...[
            Text(
              isNearDelivery
                  ? 'Gạt để bắt đầu ghi nhận thời gian chờ.'
                  : 'Đến gần điểm giao để xác nhận.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DriverSwipeAction(
              label: 'Đã đến nơi giao hàng',
              accent: AppColors.accent,
              icon: Icons.location_on_rounded,
              loading: isLoading,
              onCompleted: isNearDelivery && !isLoading
                  ? onConfirmArrival
                  : null,
            ),
          ] else ...[
            Text(
              ready ? 'Đã chờ đủ 10 phút' : 'Chờ thêm $countdown',
              style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent),
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: (wait.inSeconds / minimumWait.inSeconds).clamp(0.0, 1.0),
              color: AppColors.accent,
              backgroundColor: AppColors.accentLight,
              borderRadius: AppRadius.full,
              minHeight: AppSpacing.xs,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: ready && !isLoading ? onReportRecipient : null,
                icon: Icon(
                  ready
                      ? Icons.phone_disabled_rounded
                      : Icons.lock_clock_rounded,
                ),
                label: const Text('Không liên lạc được với khách'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  disabledForegroundColor: AppColors.textSecondary,
                  minimumSize: const Size(48, 52),
                  side: BorderSide(
                    color: ready ? AppColors.accent : AppColors.border,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.md,
                  ),
                  textStyle: AppTextStyles.labelMedium,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            wait == null
                ? 'Vẫn có thể xác nhận giao hàng ngay.'
                : 'Báo cáo cần ảnh lịch sử ≥3 cuộc gọi trong 10 phút chờ.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
