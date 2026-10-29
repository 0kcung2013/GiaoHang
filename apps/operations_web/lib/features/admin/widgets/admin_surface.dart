import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../constants/admin_strings.dart';

class AdminSurface extends StatelessWidget {
  const AdminSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: AppRadius.lg,
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

class AdminFailure extends StatelessWidget {
  const AdminFailure({
    super.key,
    required this.onRetry,
    this.message = AdminStrings.loadError,
  });
  final VoidCallback onRetry;
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.cloud_off_rounded,
          size: 32,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text(AdminStrings.retry),
        ),
      ],
    ),
  );
}

class AdminHeading extends StatelessWidget {
  const AdminHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final text = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.headingLarge),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      );
      if (constraints.maxWidth < 500 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            text,
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action!,
            ],
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: text),
          if (action != null) ...[
            const SizedBox(width: AppSpacing.lg),
            action!,
          ],
        ],
      );
    },
  );
}
