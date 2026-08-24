import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../utils/driver_profile_change_labels.dart';
import 'driver_account_section_primitives.dart';

class DriverProfileChangeStatusCard extends StatelessWidget {
  const DriverProfileChangeStatusCard({
    super.key,
    required this.request,
    required this.onView,
  });

  final DriverProfileChangeRequest request;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final visual = _StatusVisual.from(request.status);
    final changeCount = request.requestedChanges?.length ?? 0;

    return DriverAccountSectionCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: visual.color.withValues(alpha: 0.1),
                    borderRadius: AppRadius.md,
                  ),
                  child: Icon(visual.icon, color: visual.color, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverProfileChangeStatusLabel(request.status),
                        style: AppTextStyles.headingSmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _description(request.status, changeCount),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (request.decisionReason?.trim().isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: visual.color.withValues(alpha: 0.07),
                  borderRadius: AppRadius.md,
                ),
                child: Text(
                  'Phản hồi từ Admin: ${request.decisionReason!.trim()}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onView,
                style: TextButton.styleFrom(
                  foregroundColor: visual.color,
                  minimumSize: const Size(48, 48),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.full,
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Xem chi tiết'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _description(DriverProfileChangeStatus status, int count) {
    final suffix = count == 0 ? '' : ' · $count thông tin';
    return switch (status) {
      DriverProfileChangeStatus.draft => 'Chưa gửi cho Admin$suffix',
      DriverProfileChangeStatus.pending =>
        'Admin sẽ duyệt toàn bộ yêu cầu$suffix',
      DriverProfileChangeStatus.applying =>
        'Hệ thống đang cập nhật toàn bộ thay đổi$suffix',
      DriverProfileChangeStatus.approved => 'Hồ sơ đã được cập nhật$suffix',
      DriverProfileChangeStatus.rejected =>
        'Không có thông tin nào bị thay đổi$suffix',
      DriverProfileChangeStatus.cancelled =>
        'Yêu cầu không còn hiệu lực$suffix',
      DriverProfileChangeStatus.conflicted =>
        'Hãy tạo yêu cầu mới từ hồ sơ hiện tại$suffix',
    };
  }
}

class _StatusVisual {
  const _StatusVisual(this.icon, this.color);

  final IconData icon;
  final Color color;

  factory _StatusVisual.from(DriverProfileChangeStatus status) {
    return switch (status) {
      DriverProfileChangeStatus.draft => const _StatusVisual(
        Icons.edit_document,
        AppColors.info,
      ),
      DriverProfileChangeStatus.pending => const _StatusVisual(
        Icons.schedule_rounded,
        AppColors.warning,
      ),
      DriverProfileChangeStatus.applying => const _StatusVisual(
        Icons.sync_rounded,
        AppColors.info,
      ),
      DriverProfileChangeStatus.approved => const _StatusVisual(
        Icons.verified_rounded,
        AppColors.success,
      ),
      DriverProfileChangeStatus.rejected => const _StatusVisual(
        Icons.cancel_outlined,
        AppColors.error,
      ),
      DriverProfileChangeStatus.cancelled => const _StatusVisual(
        Icons.block_rounded,
        AppColors.textMuted,
      ),
      DriverProfileChangeStatus.conflicted => const _StatusVisual(
        Icons.warning_amber_rounded,
        AppColors.warning,
      ),
    };
  }
}
