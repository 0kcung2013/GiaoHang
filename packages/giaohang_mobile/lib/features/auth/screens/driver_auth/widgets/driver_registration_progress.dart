import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../driver_auth_strings.dart';

class DriverRegistrationProgress extends StatelessWidget {
  const DriverRegistrationProgress({
    super.key,
    required this.current,
    required this.total,
    required this.title,
  });
  final int current;
  final int total;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.screenH,
      AppSpacing.sm,
      AppSpacing.screenH,
      AppSpacing.lg,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${DriverAuthStrings.step(current, total)} · $title',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: AppRadius.full,
          child: LinearProgressIndicator(
            value: current / total,
            minHeight: 3,
            color: AppColors.accent,
            backgroundColor: AppColors.border,
            semanticsLabel: DriverAuthStrings.step(current, total),
          ),
        ),
      ],
    ),
  );
}
