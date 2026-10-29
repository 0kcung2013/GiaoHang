import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../constants/return_approval_strings.dart';
import '../services/return_route_quote_service.dart';
import 'support_return_quote_card.dart';

class SupportReturnApprovalContent extends StatelessWidget {
  const SupportReturnApprovalContent({
    required this.order,
    required this.quote,
    required this.quoting,
    required this.error,
    required this.instructionController,
    required this.onRecalculate,
    super.key,
  });

  final RiskOrderSummary order;
  final ReturnRouteQuote? quote;
  final bool quoting;
  final String? error;
  final TextEditingController instructionController;
  final VoidCallback onRecalculate;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        key: const Key('return-pickup-destination'),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColors.bgLight,
          borderRadius: AppRadius.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.markerPickup,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    ReturnApprovalStrings.pickupDestination,
                    style: AppTextStyles.labelMedium,
                  ),
                ),
                IconButton(
                  key: const Key('recalculate-return-route'),
                  onPressed: quoting ? null : onRecalculate,
                  tooltip: ReturnApprovalStrings.recalculateRoute,
                  icon: const Icon(Icons.refresh_rounded),
                  color: AppColors.textSecondary,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                ),
              ],
            ),
            Text(
              order.pickupAddress,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      if (quoting) ...[
        Semantics(
          liveRegion: true,
          child: Text(
            ReturnApprovalStrings.calculatingRoute,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const LinearProgressIndicator(
          minHeight: 3,
          color: AppColors.accent,
          backgroundColor: AppColors.accentLight,
          borderRadius: AppRadius.full,
        ),
      ] else if (quote != null)
        SupportReturnQuoteCard(
          configuredReturnFee: order.returnFee,
          quote: quote!,
          payer: ReturnFeePayer.platform,
          deliveryFee: order.deliveryFee,
        ),
      if (error != null)
        Semantics(
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  error!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: AppSpacing.lg),
      ExpansionTile(
        key: const Key('return-optional-instruction'),
        maintainState: true,
        tilePadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: AppColors.accent,
        collapsedIconColor: AppColors.textSecondary,
        leading: const Icon(
          Icons.edit_note_rounded,
          color: AppColors.textSecondary,
        ),
        title: Text(
          ReturnApprovalStrings.optionalInstruction,
          style: AppTextStyles.labelMedium,
        ),
        children: [
          TextField(
            key: const Key('return-driver-instruction'),
            controller: instructionController,
            minLines: 2,
            maxLines: 4,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: ReturnApprovalStrings.instructionHint,
              hintStyle: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              filled: true,
              fillColor: AppColors.bgLight,
              contentPadding: const EdgeInsets.all(AppSpacing.lg),
              border: const OutlineInputBorder(borderRadius: AppRadius.md),
              enabledBorder: const OutlineInputBorder(
                borderRadius: AppRadius.md,
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: AppRadius.md,
                borderSide: BorderSide(color: AppColors.borderFocus, width: 2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ],
  );
}
