import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../driver_offer_transfer_strings.dart';
import '../models/driver_offer_transfer_state.dart';

class DriverTransferLimitHint extends StatelessWidget {
  const DriverTransferLimitHint({super.key, required this.state});

  final DriverOfferTransferState state;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        state.isLastTransfer
            ? DriverOfferTransferStrings.lastHint
            : DriverOfferTransferStrings.remaining(state.remaining),
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySmall.copyWith(
          color: state.isLastTransfer
              ? AppColors.accent
              : AppColors.textSecondary,
        ),
      ),
    ),
  );
}
