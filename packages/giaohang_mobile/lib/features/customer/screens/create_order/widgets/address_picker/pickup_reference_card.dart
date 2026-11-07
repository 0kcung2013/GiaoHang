import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../address_picker_strings.dart';
import '../../models/address_picker_result.dart';

class PickupReferenceCard extends StatelessWidget {
  const PickupReferenceCard({
    super.key,
    required this.pickup,
    required this.onShowBoth,
  });
  final MapPickerResult pickup;
  final VoidCallback onShowBoth;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.screenH,
      0,
      AppSpacing.screenH,
      AppSpacing.md,
    ),
    child: Material(
      color: AppColors.bgLight,
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: onShowBoth,
        borderRadius: AppRadius.md,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(
                Icons.trip_origin_rounded,
                color: AppColors.markerPickup,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Tooltip(
                  message: pickup.address,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AddressPickerStrings.pickupSelected,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        pickup.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Tooltip(
                message: AddressPickerStrings.showBothStops,
                child: const Icon(
                  Icons.zoom_out_map_rounded,
                  color: AppColors.info,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
