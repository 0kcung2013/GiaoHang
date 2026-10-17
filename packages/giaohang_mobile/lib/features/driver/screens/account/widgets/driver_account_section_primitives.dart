import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

class DriverAccountSectionCard extends StatelessWidget {
  const DriverAccountSectionCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: child,
    );
  }
}

class DriverAccountSectionHeading extends StatelessWidget {
  const DriverAccountSectionHeading({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    this.isProtected = false,
  });

  final IconData icon;
  final String title;
  final Color color;
  final bool isProtected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: AppRadius.md,
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.headingSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (isProtected) ...[
          const SizedBox(width: AppSpacing.sm),
          const Tooltip(
            message: 'Chỉ Admin có thể phê duyệt thay đổi',
            child: Icon(
              Icons.lock_outline_rounded,
              color: AppColors.textMuted,
              size: 18,
            ),
          ),
        ],
      ],
    );
  }
}
