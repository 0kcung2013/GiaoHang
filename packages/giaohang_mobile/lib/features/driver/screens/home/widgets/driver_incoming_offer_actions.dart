import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../offer_transfer/models/driver_offer_transfer_state.dart';
import '../../../offer_transfer/widgets/driver_transfer_limit_hint.dart';
import '../driver_home_strings.dart';
import 'driver_offer_countdown.dart';
import 'driver_order_card_components.dart';

/// Chỉ ticker và vùng thao tác thay đổi mỗi giây; địa chỉ không rebuild theo nó.
class DriverIncomingOfferActions extends StatelessWidget {
  const DriverIncomingOfferActions({
    super.key,
    required this.expiresAt,
    required this.now,
    required this.expired,
    required this.label,
    required this.isAccepting,
    required this.isTransferring,
    required this.onAccept,
    required this.onSkip,
    this.transfers,
  });

  final DateTime expiresAt;
  final DateTime Function()? now;
  final bool expired;
  final String label;
  final bool isAccepting;
  final bool isTransferring;
  final VoidCallback? onAccept;
  final VoidCallback? onSkip;
  final DriverOfferTransferState? transfers;

  @override
  Widget build(BuildContext context) => DriverOfferCountdown(
    expiresAt: expiresAt,
    now: now,
    builder: (context, seconds) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: AppRadius.full,
          child: LinearProgressIndicator(
            value: expired ? 0 : (seconds / 45).clamp(0.0, 1.0),
            minHeight: AppSpacing.xs,
            color: AppColors.accent,
            backgroundColor: AppColors.accentLight,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DriverAcceptOrderButton(
          isLoading: isAccepting,
          label: label,
          onTap: onAccept,
          trailing:
              expired ||
                  seconds == 0 ||
                  label != DriverHomeStrings.incomingOfferAccept
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('·'),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
                    ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DriverTransferOrderButton(
          isLoading: isTransferring,
          label: DriverHomeStrings.incomingOfferSkip,
          onTap: onSkip,
        ),
        if (expired || seconds == 0)
          Text(
            DriverHomeStrings.offerExpiredLabel,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          )
        else
          Text(
            DriverHomeStrings.offerAutoTransferHint,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        if (transfers != null) DriverTransferLimitHint(state: transfers!),
      ],
    ),
  );
}
