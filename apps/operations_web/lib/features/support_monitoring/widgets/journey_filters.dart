import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../constants/journey_strings.dart';

class JourneyFilters extends StatelessWidget {
  const JourneyFilters({
    required this.controller,
    required this.onQuery,
    required this.days,
    required this.onDays,
    required this.onDateRange,
    this.rangeLabel,
    super.key,
  });
  final TextEditingController controller;
  final ValueChanged<String> onQuery;
  final int? days;
  final ValueChanged<int> onDays;
  final VoidCallback onDateRange;
  final String? rangeLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const Key('journey-search'),
        controller: controller,
        onChanged: onQuery,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: JourneyStrings.search,
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: JourneyStrings.clear,
                  onPressed: () {
                    controller.clear();
                    onQuery('');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final d in [14, 7])
            _choice(
              d == 14 ? JourneyStrings.last14 : JourneyStrings.last7,
              days == d,
              () => onDays(d),
            ),
          _choice(
            rangeLabel ?? JourneyStrings.dates,
            days == null,
            onDateRange,
            icon: Icons.date_range_outlined,
          ),
        ],
      ),
    ],
  );

  Widget _choice(
    String label,
    bool selected,
    VoidCallback onTap, {
    IconData? icon,
  }) => Semantics(
    selected: selected,
    child: TextButton(
      style: TextButton.styleFrom(
        foregroundColor: selected ? AppColors.primary : AppColors.textSecondary,
        backgroundColor: selected
            ? AppColors.info.withValues(alpha: .09)
            : AppColors.bgCard,
        side: BorderSide(
          color: selected
              ? AppColors.info.withValues(alpha: .4)
              : AppColors.border,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(label, style: AppTextStyles.labelMedium),
        ],
      ),
    ),
  );
}
