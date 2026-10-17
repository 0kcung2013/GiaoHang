import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

class DriverReturnMissionCard extends StatelessWidget {
  const DriverReturnMissionCard({
    required this.mission,
    required this.onOpen,
    super.key,
  });

  final OrderReturn? mission;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final item = mission;
    return Semantics(
      container: true,
      label: 'Nhiệm vụ hoàn đơn',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppRadius.lg,
          border: Border.all(color: AppColors.warning, width: 2),
          boxShadow: AppShadow.elevated,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.keyboard_return_rounded,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    item == null
                        ? 'Đang nhận lệnh hoàn đơn'
                        : 'Hoàn hàng về điểm chỉ định',
                    style: AppTextStyles.headingSmall.copyWith(
                      color: AppColors.textOnDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              item?.destinationAddress ??
                  'CSKH đang hoàn tất địa chỉ và chi phí hoàn trả.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textOnDark.withValues(alpha: .82),
              ),
            ),
            if (item != null) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.navigation_rounded),
                  label: Text(
                    item.canStart
                        ? 'Mở lộ trình hoàn hàng'
                        : 'Tiếp tục lộ trình',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: AppColors.textOnAccent,
                    minimumSize: const Size.fromHeight(48),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.md,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
