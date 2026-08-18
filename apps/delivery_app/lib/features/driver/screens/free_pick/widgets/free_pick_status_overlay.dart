import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

class FreePickStatusOverlay extends StatelessWidget {
  const FreePickStatusOverlay({
    super.key,
    required this.count,
    required this.isLoading,
    required this.isEnabled,
    this.error,
  });

  final int count;
  final bool isLoading;
  final bool isEnabled;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = !isEnabled
        ? (
            Icons.lock_outline_rounded,
            'Cần online, không có đơn hoặc lời mời đang chạy',
            AppColors.warning,
          )
        : error != null
        ? (Icons.error_outline_rounded, error!, AppColors.error)
        : isLoading
        ? (Icons.search_rounded, 'Đang tìm trong khu vực này', AppColors.info)
        : (
            Icons.inventory_2_rounded,
            '$count đơn FreePick trong vùng',
            AppColors.success,
          );

    return Container(
      constraints: const BoxConstraints(maxWidth: 330),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.96),
        borderRadius: AppRadius.full,
        border: Border.all(color: color.withValues(alpha: 0.24)),
        boxShadow: AppShadow.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
