import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../utils/driver_recipient_wait_strings.dart';

class DriverRecipientWaitCard extends StatelessWidget {
  const DriverRecipientWaitCard({
    super.key,
    required this.orderCode,
    required this.onRecall,
    required this.onRequestReturn,
    required this.onContactSupport,
    required this.onMinimize,
    required this.onRetry,
    this.error,
    this.sending = false,
    this.returnRequested = false,
  });

  final String orderCode;
  final VoidCallback onRecall;
  final VoidCallback? onRequestReturn;
  final VoidCallback onContactSupport;
  final VoidCallback onMinimize;
  final VoidCallback onRetry;
  final String? error;
  final bool sending;
  final bool returnRequested;

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
              returnRequested
                  ? DriverRecipientWaitStrings.waiting
                  : DriverRecipientWaitStrings.requestTitle,
              style: AppTextStyles.headingLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              returnRequested
                  ? DriverRecipientWaitStrings.returnPending
                  : DriverRecipientWaitStrings.returnHint,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                error!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
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
                  : returnRequested
                  ? onContactSupport
                  : onRequestReturn,
              child: Text(
                sending
                    ? DriverRecipientWaitStrings.sending
                    : returnRequested
                    ? DriverRecipientWaitStrings.contactSupport
                    : DriverRecipientWaitStrings.sendReturn,
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
                if (!returnRequested)
                  TextButton(
                    onPressed: onContactSupport,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      textStyle: AppTextStyles.labelMedium,
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text(
                      DriverRecipientWaitStrings.contactSupport,
                    ),
                  ),
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
