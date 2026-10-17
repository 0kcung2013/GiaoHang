import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:latlong2/latlong.dart';
import 'package:giaohang_domain/giaohang_domain.dart' show VietnamTime;

import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/money_formatter.dart';
import '../driver_home_strings.dart';
import 'driver_order_distance_summary.dart';

abstract final class DriverOrderPresentationStrings {
  static const newOrder = 'Đơn mới';
  static const earning = 'Thực nhận sau khi giao thành công';
  static const total = 'Tổng cộng';
  static const estimatedDistance = 'Quãng đường ước tính';
  static const distanceUnavailable = 'Chưa xác định quãng đường';
  static const pickup = 'Điểm lấy hàng';
  static const delivery = 'Điểm giao hàng';
  static const details = 'Thông tin đơn';
  static const cargo = 'Hàng hóa';
  static const emptyCargo = 'Chưa có thông tin hàng hóa';
  static const note = 'Lưu ý giao hàng';
  static const map = 'MAP';
  static const back = 'Quay lại';
  static const retry = 'Thử lại';
  static const loadError = 'Chưa tải được đơn đã nhận';
  static const viewPhoto = 'Xem ảnh hàng hóa';
  static const closePhoto = 'Đóng ảnh';
  static const freePickAccept = 'Nhận đơn FreePick';
  static const accepting = 'Đang nhận đơn';
  static const transferring = 'Đang chuyển đơn';
  static String freePickPosition(int position, int total) =>
      'FreePick $position/$total';
}

class DriverOfferEarning extends StatelessWidget {
  const DriverOfferEarning({
    super.key,
    required this.amount,
    this.dark = false,
  });

  final int amount;
  final bool dark;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        DriverOrderPresentationStrings.earning,
        style: AppTextStyles.bodySmall.copyWith(
          color: dark ? AppColors.textOnDark : AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        formatVnd(amount),
        style: AppTextStyles.displayLarge.copyWith(
          color: dark ? AppColors.accent : AppColors.primary,
        ),
      ),
    ],
  );
}

/// Chỉ hiển thị lộ trình, không đọc ảnh, loại hàng hoặc giá trị hàng hóa.
class DriverOrderRouteSummary extends StatelessWidget {
  const DriverOrderRouteSummary({
    super.key,
    required this.order,
    this.driverId,
    this.driverPosition,
    this.showDistance = true,
    this.prominentAddresses = false,
    this.showEstimatedTimes = false,
    this.compactDistance = false,
  });

  final OrderModel order;
  final String? driverId;
  final LatLng? driverPosition;
  final bool showDistance;
  final bool prominentAddresses;
  final bool showEstimatedTimes;
  final bool compactDistance;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (showDistance) ...[
        DriverOrderDistanceSummary(
          order: order,
          driverId: driverId,
          driverPosition: driverPosition,
          compact: compactDistance,
        ),
        SizedBox(height: compactDistance ? AppSpacing.lg : AppSpacing.xl2),
      ],
      _RouteStop(
        number: '1',
        label: DriverOrderPresentationStrings.pickup,
        address: order.pickupAddress,
        color: AppColors.markerPickup,
        connects: true,
        prominent: prominentAddresses,
        estimatedAt: showEstimatedTimes ? order.estimatedPickupAt : null,
      ),
      _RouteStop(
        number: '2',
        label: DriverOrderPresentationStrings.delivery,
        address: order.deliveryAddress,
        color: AppColors.markerDrop,
        prominent: prominentAddresses,
        estimatedAt: showEstimatedTimes ? order.estimatedDeliveryAt : null,
      ),
    ],
  );
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.number,
    required this.label,
    required this.address,
    required this.color,
    this.connects = false,
    this.prominent = false,
    this.estimatedAt,
  });

  final String number;
  final String label;
  final String address;
  final Color color;
  final bool connects;
  final bool prominent;
  final DateTime? estimatedAt;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppSpacing.xl3,
          child: Column(
            children: [
              Container(
                width: AppSpacing.xl3,
                height: AppSpacing.xl3,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color),
                ),
                child: Text(
                  number,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (connects)
                Expanded(
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    color: AppColors.border,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: connects ? AppSpacing.xl2 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: prominent
                      ? AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        )
                      : AppTextStyles.headingSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  address,
                  style: prominent
                      ? AppTextStyles.headingSmall.copyWith(
                          color: AppColors.primary,
                        )
                      : AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                ),
                if (estimatedAt != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${DriverHomeStrings.incomingOfferTimeHint} · ${_timeText(estimatedAt!)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );

  String _timeText(DateTime value) {
    final local = VietnamTime.toWallClock(value);
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
