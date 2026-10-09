import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../utils/driver_recipient_wait_strings.dart';

class DriverRecipientWaitCard extends StatelessWidget {
  const DriverRecipientWaitCard({
    super.key,
    required this.orderCode,
    required this.pickupAddress,
    required this.remaining,
    required this.onRecall,
    required this.onRequestReturn,
    required this.onOpenReport,
    required this.onMinimize,
    required this.onRetry,
    this.error,
    this.sending = false,
    this.returnRequested = false,
  });

  final String orderCode;
  final String pickupAddress;
  final Duration? remaining;
  final VoidCallback onRecall;
  final VoidCallback? onRequestReturn;
  final VoidCallback onOpenReport;
  final VoidCallback onMinimize;
  final VoidCallback onRetry;
  final String? error;
  final bool sending;
  final bool returnRequested;

  bool get expired => remaining == Duration.zero;

  static String formatRemaining(Duration remaining) {
    final seconds = (remaining.inMilliseconds / 1000).ceil();
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final actionStyle = FilledButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.textOnAccent,
      minimumSize: const Size(double.infinity, 48),
      padding: const EdgeInsets.all(AppSpacing.md),
      textStyle: AppTextStyles.labelLarge,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
    );
    return Material(
      color: AppColors.bgCard,
      borderRadius: AppRadius.xl2,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(orderCode, style: AppTextStyles.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              expired
                  ? DriverRecipientWaitStrings.expired
                  : DriverRecipientWaitStrings.waiting,
              style: AppTextStyles.headingLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              expired
                  ? DriverRecipientWaitStrings.returnHint
                  : DriverRecipientWaitStrings.hint,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (!expired) ...[
              Text(
                DriverRecipientWaitStrings.timer,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                remaining == null
                    ? DriverRecipientWaitStrings.syncing
                    : formatRemaining(remaining!),
                style: remaining == null
                    ? AppTextStyles.bodyMedium
                    : AppTextStyles.displayLarge,
              ),
              const SizedBox(height: AppSpacing.xl),
            ] else ...[
              Text(pickupAddress, style: AppTextStyles.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              if (returnRequested) ...[
                Text(
                  DriverRecipientWaitStrings.returnSent,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  DriverRecipientWaitStrings.returnPending,
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.bgLight,
                borderRadius: AppRadius.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${DriverRecipientWaitStrings.fee} · '
                    '${DriverRecipientWaitStrings.rate}',
                    style: AppTextStyles.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    DriverRecipientWaitStrings.payer,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                error!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
              if (remaining == null)
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: AppColors.primary,
                    textStyle: AppTextStyles.labelMedium,
                  ),
                  child: const Text(DriverRecipientWaitStrings.retry),
                ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              style: actionStyle,
              onPressed: sending
                  ? null
                  : expired && !returnRequested
                  ? onRequestReturn
                  : expired
                  ? onOpenReport
                  : onRecall,
              child: Text(
                sending
                    ? DriverRecipientWaitStrings.sending
                    : expired && !returnRequested
                    ? DriverRecipientWaitStrings.sendReturn
                    : expired
                    ? DriverRecipientWaitStrings.report
                    : DriverRecipientWaitStrings.recall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: onMinimize,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    textStyle: AppTextStyles.labelMedium,
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Text(DriverRecipientWaitStrings.minimize),
                ),
                if (!expired)
                  TextButton(
                    onPressed: onOpenReport,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      textStyle: AppTextStyles.labelMedium,
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text(DriverRecipientWaitStrings.report),
                  ),
                if (expired)
                  TextButton(
                    onPressed: onRecall,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      textStyle: AppTextStyles.labelMedium,
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text(DriverRecipientWaitStrings.recall),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
