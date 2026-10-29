import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../review_history_strings.dart';

class ReviewHistoryControls extends StatelessWidget {
  const ReviewHistoryControls({
    super.key,
    required this.rating,
    required this.onSelected,
  });

  final int? rating;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        label: ReviewHistoryStrings.filter,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final value in <int?>[null, 5, 4, 3, 2, 1])
              OutlinedButton(
                onPressed: () => onSelected(value),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  backgroundColor: value == rating
                      ? AppColors.accentLight
                      : AppColors.bgCard,
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: value == rating
                        ? AppColors.accent
                        : AppColors.border,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.full,
                  ),
                  textStyle: AppTextStyles.labelMedium,
                ),
                child: Semantics(
                  selected: value == rating,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (value == rating) ...[
                        const Icon(Icons.check_rounded, size: 16),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Text(
                        value == null
                            ? ReviewHistoryStrings.all
                            : ReviewHistoryStrings.rating(value),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Row(
        children: [
          const Icon(
            Icons.sort_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              ReviewHistoryStrings.newestFirst,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
