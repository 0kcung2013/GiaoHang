import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

class ReportSurface extends StatelessWidget {
  const ReportSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: AppRadius.lg,
      border: Border.all(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class ReportLabelValue extends StatelessWidget {
  const ReportLabelValue({super.key, required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 260 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final name = Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        );
        final content = SelectableText(
          value,
          style: AppTextStyles.labelMedium,
          textAlign: stacked ? TextAlign.left : TextAlign.right,
        );
        return stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  name,
                  const SizedBox(height: AppSpacing.xs),
                  content,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: name),
                  const SizedBox(width: AppSpacing.lg),
                  Flexible(fit: FlexFit.tight, child: content),
                ],
              );
      },
    ),
  );
}
