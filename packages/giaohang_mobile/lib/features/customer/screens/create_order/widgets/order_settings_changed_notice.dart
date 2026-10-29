import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

class OrderSettingsChangedNotice extends StatelessWidget {
  const OrderSettingsChangedNotice({super.key});

  static const action = 'Xem giá mới';

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Cấu hình đã thay đổi. Xem lại giá và hạn mức trước khi đặt đơn.',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    ),
  );
}
