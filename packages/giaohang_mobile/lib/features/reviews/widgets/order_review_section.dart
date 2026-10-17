import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/review_model.dart';
import '../../../core/providers/customer_providers.dart';
import 'submit_review_sheet.dart';

/// Khối đánh giá trên chi tiết đơn / tracking khi status = delivered.
class OrderReviewSection extends ConsumerWidget {
  const OrderReviewSection({super.key, required this.order, this.driverName});

  final OrderModel order;
  final String? driverName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (order.status != 'delivered') {
      return const SizedBox.shrink();
    }
    if (order.driverId == null || order.driverId!.isEmpty) {
      return const SizedBox.shrink();
    }

    final reviewAsync = ref.watch(orderReviewProvider(order.id));

    return reviewAsync.when(
      loading: () => const _ReviewCardShell(
        child: SizedBox(
          height: 48,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (_, _) => _ReviewCardShell(
        child: Text(
          'Không tải được trạng thái đánh giá',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
      data: (review) {
        if (review != null) {
          return _ReviewedCard(review: review);
        }
        return _PendingReviewCard(order: order, driverName: driverName);
      },
    );
  }
}

class _ReviewCardShell extends StatelessWidget {
  const _ReviewCardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: AppRadius.sm,
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Đánh giá tài xế',
                style: AppTextStyles.headingSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _PendingReviewCard extends StatelessWidget {
  const _PendingReviewCard({required this.order, this.driverName});

  final OrderModel order;
  final String? driverName;

  @override
  Widget build(BuildContext context) {
    return _ReviewCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Đơn đã giao thành công. Hãy chấm điểm tài xế để cải thiện dịch vụ.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
            onPressed: () async {
              await showSubmitReviewSheet(
                context: context,
                order: order,
                driverName: driverName,
              );
            },
            icon: const Icon(Icons.star_outline_rounded, size: 20),
            label: const Text('Đánh giá ngay'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.textOnAccent,
              minimumSize: const Size.fromHeight(46),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewedCard extends StatelessWidget {
  const _ReviewedCard({required this.review});
  final ReviewModel review;

  @override
  Widget build(BuildContext context) {
    return _ReviewCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(5, (i) {
                final filled = i < review.rating;
                return Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 20,
                  color: filled ? AppColors.warning : AppColors.textMuted,
                );
              }),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${review.rating}/5',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              review.comment!.trim(),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in review.tags)
                  Chip(
                    label: Text(_tagLabel(id)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelStyle: AppTextStyles.labelSmall,
                    backgroundColor: AppColors.bgLight,
                    side: const BorderSide(color: AppColors.border),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Bạn đã đánh giá đơn này',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.success),
          ),
        ],
      ),
    );
  }

  String _tagLabel(String id) {
    for (final t in customerDriverReviewTags) {
      if (t.id == id) return t.label;
    }
    return id;
  }
}
