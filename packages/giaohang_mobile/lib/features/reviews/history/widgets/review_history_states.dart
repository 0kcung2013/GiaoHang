import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../review_history_strings.dart';

class ReviewHistoryMessage extends StatelessWidget {
  const ReviewHistoryMessage({
    super.key,
    required this.title,
    required this.hint,
    required this.action,
    required this.onAction,
    this.failed = false,
  });

  final String title, hint, action;
  final VoidCallback onAction;
  final bool failed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl3),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: const BoxDecoration(
            color: AppColors.accentLight,
            shape: BoxShape.circle,
          ),
          child: Icon(
            failed ? Icons.cloud_off_rounded : Icons.rate_review_rounded,
            color: AppColors.primary,
            size: 32,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.headingMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton(
          onPressed: onAction,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(48, 48),
            side: const BorderSide(color: AppColors.border),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
            textStyle: AppTextStyles.labelMedium,
          ),
          child: Text(action),
        ),
      ],
    ),
  );
}

class ReviewHistoryLoading extends StatelessWidget {
  const ReviewHistoryLoading({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: ReviewHistoryStrings.loading,
    child: ExcludeSemantics(
      child: Column(
        children: [
          const LinearProgressIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.accentLight,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: AppRadius.xl,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final width in [120.0, double.infinity, 200.0])
                    Container(
                      width: width,
                      height: 16,
                      margin: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.border,
                        borderRadius: AppRadius.sm,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
