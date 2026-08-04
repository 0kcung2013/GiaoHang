import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../order_detail_strings.dart';
import 'order_detail_information.dart';

const orderCancelButtonKey = Key('order-cancel-button');

class OrderCancelSection extends StatelessWidget {
  const OrderCancelSection({
    super.key,
    required this.controller,
    required this.showReasonInput,
    required this.isCancelling,
    required this.warnBeforeCancel,
    this.disabledReason,
    required this.onShowReasonInput,
    required this.onCancel,
  });

  final TextEditingController controller;
  final bool showReasonInput;
  final bool isCancelling;
  final bool warnBeforeCancel;
  final String? disabledReason;
  final VoidCallback onShowReasonInput;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isLocked = disabledReason != null;

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
                  isLocked
                      ? Icons.lock_outline_rounded
                      : warnBeforeCancel
                      ? Icons.warning_amber_rounded
                      : Icons.info_outline_rounded,
                  color: isLocked
                      ? AppColors.textMuted
                      : warnBeforeCancel
                      ? AppColors.warning
                      : AppColors.textSecondary,
                  size: 19,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    isLocked
                        ? disabledReason!
                        : warnBeforeCancel
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
          if (isLocked) ...[
            const SizedBox(height: AppSpacing.md),
            _CancelButton(
              label: OrderDetailStrings.cancelLockedAction,
              onTap: null,
              disabledHint: disabledReason,
            ),
          ] else if (showReasonInput) ...[
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
  const _CancelButton({
    required this.label,
    required this.onTap,
    this.disabledHint,
  });

  final String label;
  final VoidCallback? onTap;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: orderCancelButtonKey,
      button: true,
      enabled: onTap != null,
      label: label,
      hint: disabledHint,
      child: ExcludeSemantics(
        child: Material(
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
        ),
      ),
    );
  }
}
