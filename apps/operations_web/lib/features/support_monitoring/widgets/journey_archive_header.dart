import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../constants/journey_strings.dart';

class JourneyArchiveHeader extends StatelessWidget {
  const JourneyArchiveHeader({
    required this.onCases,
    required this.onRefresh,
    super.key,
  });
  final VoidCallback onCases;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xl2),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              JourneyStrings.title,
              style: AppTextStyles.headingLarge.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              JourneyStrings.subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: JourneyStrings.refresh,
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              color: AppColors.textSecondary,
            ),
            OutlinedButton.icon(
              onPressed: onCases,
              icon: const Icon(Icons.fact_check_outlined, size: 20),
              label: const Text(JourneyStrings.cases),
            ),
          ],
        ),
      ],
    ),
  );
}
