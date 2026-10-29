import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../core/models/review_model.dart';
import '../review_strings.dart';

class ReviewChoices extends StatelessWidget {
  const ReviewChoices({
    super.key,
    required this.rating,
    required this.tags,
    required this.options,
    required this.enabled,
    required this.onRating,
    required this.onTag,
  });

  final int rating;
  final Set<String> tags;
  final List<ReviewTagOption> options;
  final bool enabled;
  final ValueChanged<int> onRating;
  final void Function(String, bool) onTag;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var star = 1; star <= 5; star++)
            Semantics(
              selected: rating == star,
              child: IconButton(
                tooltip: ReviewStrings.stars(star),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: EdgeInsets.zero,
                onPressed: enabled ? () => onRating(star) : null,
                iconSize: 36,
                icon: Icon(
                  star <= rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: star <= rating
                      ? AppColors.warning
                      : AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        rating == 0
            ? ReviewStrings.chooseStars
            : '${ReviewStrings.stars(rating)} / 5',
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        alignment: WrapAlignment.center,
        children: [
          for (final option in options)
            FilterChip(
              label: Text(option.label),
              selected: tags.contains(option.id),
              onSelected: enabled
                  ? (selected) => onTag(option.id, selected)
                  : null,
              selectedColor: AppColors.accentLight,
              checkmarkColor: AppColors.accent,
              labelStyle: AppTextStyles.labelSmall.copyWith(
                color: tags.contains(option.id)
                    ? AppColors.accent
                    : AppColors.textSecondary,
              ),
              side: BorderSide(
                color: tags.contains(option.id)
                    ? AppColors.accent
                    : AppColors.border,
              ),
            ),
        ],
      ),
    ],
  );
}
