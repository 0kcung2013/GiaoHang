import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../core/location/driver_location_producer_policy.dart';

class DriverGpsSheetHeader extends StatelessWidget {
  const DriverGpsSheetHeader({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: AppRadius.full,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.accentLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.gps_fixed_rounded,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kiểm tra vị trí',
                      style: AppTextStyles.headingMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      email.isEmpty ? 'Đang đọc thông tin tài xế...' : email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Đóng bảng kiểm tra vị trí',
                child: IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DriverGpsDemoBanner extends StatelessWidget {
  const DriverGpsDemoBanner({
    super.key,
    required this.locationMode,
    required this.hasOffset,
    required this.isDemoAccount,
    required this.offsetMeters,
  });

  final DriverLocationMode locationMode;
  final bool hasOffset;
  final bool isDemoAccount;
  final double offsetMeters;

  @override
  Widget build(BuildContext context) {
    final isUsingDeviceGps = locationMode == DriverLocationMode.deviceGps;
    final title = isUsingDeviceGps
        ? 'Đang dùng vị trí hiện tại'
        : hasOffset
        ? 'Chế độ demo đang bật'
        : isDemoAccount
        ? 'Offset demo đang tắt'
        : 'Đang dùng GPS thực tế';
    final description = isUsingDeviceGps
        ? 'Tuyến đường và khoảng cách sẽ tính từ GPS thiết bị.'
        : hasOffset
        ? 'Tài khoản này lệch ${(offsetMeters / 1000).toStringAsFixed(1)} km '
              'so với GPS của thiết bị.'
        : isDemoAccount
        ? 'Tài khoản demo hiện chưa được dịch chuyển vị trí.'
        : 'Tài khoản này không có offset vị trí.';
    final color = isUsingDeviceGps
        ? AppColors.info
        : hasOffset
        ? AppColors.accent
        : isDemoAccount
        ? AppColors.warning
        : AppColors.success;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: AppRadius.lg,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isUsingDeviceGps
                ? Icons.my_location_rounded
                : hasOffset
                ? Icons.compare_arrows_rounded
                : Icons.location_on_rounded,
            color: color,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelLarge.copyWith(color: color),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DriverGpsCoordinateCard extends StatelessWidget {
  const DriverGpsCoordinateCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.address,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.md,
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  address,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DriverGpsStoredCard extends StatelessWidget {
  const DriverGpsStoredCard({
    super.key,
    required this.position,
    required this.distanceMeters,
    required this.isMatched,
    required this.address,
  });

  final LatLng? position;
  final double? distanceMeters;
  final bool isMatched;
  final String address;

  @override
  Widget build(BuildContext context) {
    final color = isMatched ? AppColors.success : AppColors.warning;
    final subtitle = position == null
        ? 'Chưa có tọa độ trong hồ sơ tài xế'
        : isMatched
        ? 'Đã khớp vị trí gửi lên hệ thống'
        : 'Khác vị trí cần gửi ${_formatDistance(distanceMeters ?? 0)}';

    return DriverGpsCoordinateCard(
      icon: isMatched ? Icons.cloud_done_rounded : Icons.cloud_sync_outlined,
      color: color,
      title: 'Đang lưu trên Supabase',
      subtitle: subtitle,
      address: address,
    );
  }

  static String _formatDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }
}

class DriverGpsInlineMessage extends StatelessWidget {
  const DriverGpsInlineMessage({
    super.key,
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.md,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
