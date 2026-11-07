import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../dispatch_preferences.dart';
import '../dispatch_preferences_strings.dart';

String dispatchModeLabel(DispatchMode mode) => switch (mode) {
  DispatchMode.nearby => DispatchPreferencesStrings.nearby,
  DispatchMode.area => DispatchPreferencesStrings.area,
  DispatchMode.destination => DispatchPreferencesStrings.destination,
};
IconData dispatchModeIcon(DispatchMode mode) => switch (mode) {
  DispatchMode.nearby => Icons.radar_rounded,
  DispatchMode.area => Icons.map_rounded,
  DispatchMode.destination => Icons.near_me_rounded,
};

class DispatchModeSelector extends StatelessWidget {
  const DispatchModeSelector({
    super.key,
    required this.mode,
    required this.onChanged,
  });
  final DispatchMode mode;
  final ValueChanged<DispatchMode>? onChanged;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final value in DispatchMode.values) ...[
          if (value != DispatchMode.nearby)
            const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Semantics(
              button: true,
              selected: mode == value,
              child: Material(
                color: mode == value ? AppColors.accentLight : AppColors.bgCard,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.lg,
                  side: BorderSide(
                    color: mode == value ? AppColors.accent : AppColors.border,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onChanged == null ? null : () => onChanged!(value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.lg,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          dispatchModeIcon(value),
                          color: mode == value
                              ? AppColors.accent
                              : AppColors.textSecondary,
                          size: 26,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          dispatchModeLabel(value),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: mode == value
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
