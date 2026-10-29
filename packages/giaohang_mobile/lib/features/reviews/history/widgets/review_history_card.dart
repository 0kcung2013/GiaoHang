import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/review_history_entry.dart';
import '../review_history_strings.dart';
import '../utils/review_history_format.dart';

class ReviewHistoryCard extends StatelessWidget {
  const ReviewHistoryCard({super.key, required this.entry, this.onOpenOrder});

  final ReviewHistoryEntry entry;
  final VoidCallback? onOpenOrder;

  @override
  Widget build(BuildContext context) {
    final review = entry.review;
    final comment = review.comment?.trim();
    final address = entry.deliveryAddress?.trim();
    final code = entry.trackingCode?.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: ReviewHistoryStrings.rating(review.rating),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 0; i < 5; i++)
                      Icon(
                        i < review.rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: i < review.rating
                            ? AppColors.warning
                            : AppColors.textSecondary,
                        size: 24,
                      ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${review.rating}/5',
                      style: AppTextStyles.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              reviewHistoryDate(review.createdAt),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (comment?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.md),
              Text(comment!, style: AppTextStyles.bodyMedium),
            ],
            if (review.tags.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final tag in review.tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.bgLight,
                        borderRadius: AppRadius.sm,
                      ),
                      child: Text(
                        reviewHistoryTag(tag),
                        style: AppTextStyles.labelMedium,
                      ),
                    ),
                ],
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Divider(height: 1, color: AppColors.border),
            ),
            if (code?.isNotEmpty == true)
              Text(code!, style: AppTextStyles.mono),
            if (address?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 20,
                    color: AppColors.markerDrop,
                    semanticLabel: ReviewHistoryStrings.delivery,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      address!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (onOpenOrder != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: ValueKey('review-order-${review.id}'),
                  onPressed: onOpenOrder,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(48, 48),
                    textStyle: AppTextStyles.labelMedium,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  iconAlignment: IconAlignment.end,
                  label: const Text(ReviewHistoryStrings.order),
                ),
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                ReviewHistoryStrings.unavailableOrder,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
