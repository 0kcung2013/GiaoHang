import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:latlong2/latlong.dart';

import '../destination_picker_screen.dart';
import '../dispatch_preferences.dart';
import '../dispatch_preferences_strings.dart';
import 'destination_route_map.dart';
import 'dispatch_mode_selector.dart';
import 'dispatch_selection_field.dart';
import 'operating_area_fields.dart';

class DispatchModeForm extends StatelessWidget {
  const DispatchModeForm({
    super.key,
    required this.mode,
    required this.enabled,
    required this.areaId,
    required this.onAreaChanged,
    required this.deliveryLimit,
    required this.onLimitChanged,
    required this.destination,
    required this.origin,
    required this.onPickDestination,
    required this.expired,
  });
  final DispatchMode mode;
  final bool enabled;
  final String? areaId;
  final ValueChanged<String?> onAreaChanged;
  final int? deliveryLimit;
  final ValueChanged<int?> onLimitChanged;
  final DispatchDestination? destination;
  final LatLng? origin;
  final VoidCallback onPickDestination;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final title = switch (mode) {
      DispatchMode.nearby => DispatchPreferencesStrings.nearbyTitle,
      DispatchMode.area => DispatchPreferencesStrings.areaTitle,
      DispatchMode.destination => DispatchPreferencesStrings.destinationTitle,
    };
    final description = switch (mode) {
      DispatchMode.nearby => DispatchPreferencesStrings.nearbyDescription,
      DispatchMode.area => DispatchPreferencesStrings.areaHint,
      DispatchMode.destination => DispatchPreferencesStrings.destinationHint,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: AppRadius.md,
              ),
              child: Icon(
                dispatchModeIcon(mode),
                color: AppColors.accent,
                size: 26,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (mode == DispatchMode.nearby) ...[
              Text(
                DispatchPreferencesStrings.deliveryRange,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final option in <int?, String>{
                    5000: DispatchPreferencesStrings.underFive,
                    10000: DispatchPreferencesStrings.underTen,
                    null: DispatchPreferencesStrings.unlimited,
                  }.entries)
                    ChoiceChip(
                      label: Text(option.value),
                      selected: deliveryLimit == option.key,
                      onSelected: !enabled
                          ? null
                          : (_) => onLimitChanged(option.key),
                      labelStyle: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      backgroundColor: AppColors.bgLight,
                      selectedColor: AppColors.accentLight,
                      side: BorderSide(
                        color: deliveryLimit == option.key
                            ? AppColors.accent
                            : AppColors.border,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.md,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.md,
                      ),
                    ),
                ],
              ),
            ],
            if (mode == DispatchMode.area)
              OperatingAreaFields(
                areaId: areaId,
                onChanged: onAreaChanged,
                enabled: enabled,
              ),
            if (mode == DispatchMode.destination) ...[
              DispatchSelectionField(
                label: DispatchPreferencesStrings.destinationField,
                icon: Icons.location_on_rounded,
                value:
                    destination?.label ??
                    DispatchPreferencesStrings.destinationPlaceholder,
                placeholder: destination == null,
                onTap: enabled ? onPickDestination : null,
              ),
              if (destination != null && origin != null) ...[
                const SizedBox(height: AppSpacing.lg),
                DestinationRouteMap(
                  origin: origin,
                  destination: destination!.point,
                  height: 220,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                expired
                    ? DispatchPreferencesStrings.expired
                    : DispatchPreferencesStrings.destinationSession,
                style: AppTextStyles.bodySmall.copyWith(
                  color: expired ? AppColors.error : AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.trip_origin_rounded,
                  size: 18,
                  color: AppColors.info,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    mode == DispatchMode.destination
                        ? DispatchPreferencesStrings.pickupThree
                        : DispatchPreferencesStrings.pickupTwo,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
