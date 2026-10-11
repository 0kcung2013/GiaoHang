import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../utils/support_order_information_strings.dart';

class SupportOrderInfoSection extends StatelessWidget {
  const SupportOrderInfoSection({
    required this.title,
    required this.icon,
    required this.child,
    super.key,
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.bgLight,
      borderRadius: AppRadius.lg,
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.accent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(title, style: AppTextStyles.headingSmall)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        child,
      ],
    ),
  );
}

class SupportOrderInfoFact extends StatelessWidget {
  const SupportOrderInfoFact({required this.label, this.value, super.key});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      SelectableText(
        value?.trim().isNotEmpty == true
            ? value!
            : SupportOrderInformationStrings.missing,
        style: AppTextStyles.bodyMedium,
      ),
    ],
  );
}

class SupportOrderInfoFacts extends StatelessWidget {
  const SupportOrderInfoFacts({required this.children, super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final twoColumns =
          constraints.maxWidth >= 480 &&
          MediaQuery.textScalerOf(context).scale(1) < 1.4;
      final width = twoColumns
          ? (constraints.maxWidth - AppSpacing.xl) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: AppSpacing.xl,
        runSpacing: AppSpacing.lg,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
