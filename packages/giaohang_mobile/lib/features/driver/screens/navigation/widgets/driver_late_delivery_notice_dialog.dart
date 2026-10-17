import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../models/driver_late_delivery_notice.dart';

Future<void> showDriverLateDeliveryNoticeDialog(
  BuildContext context,
  DriverLateDeliveryNotice notice,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => Dialog(
    backgroundColor: AppColors.bgDark,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl2),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            notice.lockTriggered
                ? Icons.lock_clock_rounded
                : Icons.timer_off_rounded,
            color: AppColors.warning,
            size: 40,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            notice.lockTriggered ? 'Tạm khóa nhận đơn' : 'Đơn này giao muộn',
            textAlign: TextAlign.center,
            style: AppTextStyles.headingMedium.copyWith(
              color: AppColors.textOnDark,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.bgDarkCard,
              borderRadius: AppRadius.lg,
            ),
            child: Column(
              children: [
                Text(
                  '${notice.count}/3 đơn giao muộn',
                  style: AppTextStyles.headingLarge.copyWith(
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Trong 2 giờ gần nhất',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            notice.lockTriggered
                ? 'Bạn bị khóa nhận đơn mới 30 phút. Hết thời gian sẽ tự mở lại.'
                : notice.count >= 3
                ? 'Đã đạt ngưỡng 3 đơn muộn trong 2 giờ. Thời hạn khóa nhận đơn hiện tại vẫn giữ nguyên.'
                : 'Thêm ${3 - notice.count} đơn giao muộn trong cùng khoảng 2 giờ sẽ bị khóa nhận đơn mới 30 phút.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textOnDark,
            ),
          ),
          if (notice.lockTriggered) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Đơn đang giao vẫn tiếp tục.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textOnDark,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl2),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textOnAccent,
                minimumSize: const Size(48, 48),
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đã hiểu'),
            ),
          ),
        ],
      ),
    ),
  ),
);
