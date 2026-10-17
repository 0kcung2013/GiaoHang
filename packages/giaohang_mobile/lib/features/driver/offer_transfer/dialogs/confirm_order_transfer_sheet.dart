import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../driver_offer_transfer_strings.dart';
import '../models/driver_offer_transfer_state.dart';

Future<bool> showConfirmOrderTransferSheet(
  BuildContext context, {
  DriverOfferTransferState? transfers,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _TransferSheet(transfers: transfers),
    ) ??
    false;

class _TransferSheet extends StatelessWidget {
  const _TransferSheet({this.transfers});

  final DriverOfferTransferState? transfers;

  @override
  Widget build(BuildContext context) {
    final last = transfers?.isLastTransfer ?? false;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: AppRadius.full,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl2),
            Icon(
              last ? Icons.lock_clock_rounded : Icons.swap_horiz_rounded,
              color: AppColors.accent,
              size: 32,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              last
                  ? DriverOfferTransferStrings.lastTitle
                  : DriverOfferTransferStrings.confirmTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.headingMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              last
                  ? DriverOfferTransferStrings.lastDescription
                  : DriverOfferTransferStrings.confirmDescription,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (!last && transfers != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                DriverOfferTransferStrings.remaining(transfers!.remaining),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl2),
            FilledButton(
              key: const Key('confirm-driver-offer-transfer'),
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textOnAccent,
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.all(AppSpacing.md),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
                textStyle: AppTextStyles.labelLarge,
              ),
              child: Text(
                last
                    ? DriverOfferTransferStrings.confirmLast
                    : DriverOfferTransferStrings.confirm,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                minimumSize: const Size.fromHeight(48),
                textStyle: AppTextStyles.labelLarge,
              ),
              child: const Text(DriverOfferTransferStrings.goBack),
            ),
          ],
        ),
      ),
    );
  }
}
