import 'package:flutter/material.dart';

import '../../../../../../core/constants/app_theme.dart';
import '../order_detail_strings.dart';
import 'order_detail_information.dart';

class OrderCancelSection extends StatelessWidget {
  const OrderCancelSection({
    super.key,
    required this.controller,
    required this.showReasonInput,
    required this.isCancelling,
    required this.warnBeforeCancel,
    required this.onShowReasonInput,
    required this.onCancel,
  });

  final TextEditingController controller;
  final bool showReasonInput;
  final bool isCancelling;
  final bool warnBeforeCancel;
  final VoidCallback onShowReasonInput;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return OrderDetailSectionSurface(
      title: OrderDetailStrings.cancelTitle,
      icon: Icons.cancel_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: warnBeforeCancel
                  ? AppColors.warning.withValues(alpha: 0.08)
                  : AppColors.bgLight,
              borderRadius: AppRadius.md,
              border: Border.all(
                color: warnBeforeCancel
                    ? AppColors.warning.withValues(alpha: 0.28)
                    : AppColors.border,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  warnBeforeCancel
                      ? Icons.warning_amber_rounded
                      : Icons.info_outline_rounded,
                  color: warnBeforeCancel
                      ? AppColors.warning
                      : AppColors.textSecondary,
                  size: 19,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    warnBeforeCancel
                        ? OrderDetailStrings.riskyCancelDescription
                        : OrderDetailStrings.cancelDescription,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showReasonInput) ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 4,
              enabled: !isCancelling,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: OrderDetailStrings.cancelReasonHint,
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: AppColors.bgLight,
                contentPadding: const EdgeInsets.all(AppSpacing.lg),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.lg,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.lg,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.lg,
                  borderSide: const BorderSide(
                    color: AppColors.accent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _CancelButton(
              label: isCancelling
                  ? OrderDetailStrings.cancellingAction
                  : OrderDetailStrings.confirmCancelAction,
              onTap: isCancelling ? null : onCancel,
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            _CancelButton(
              label: OrderDetailStrings.cancelAction,
              onTap: onShowReasonInput,
            ),
          ],
        ],
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.full,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: onTap == null
                ? AppColors.textMuted.withValues(alpha: 0.16)
                : AppColors.bgCard,
            borderRadius: AppRadius.full,
            border: Border.all(
              color: onTap == null ? AppColors.border : AppColors.error,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelMedium.copyWith(
              color: onTap == null ? AppColors.textMuted : AppColors.error,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
