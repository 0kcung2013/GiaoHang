import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../core/providers/customer_providers.dart';
import '../../widgets/order_assignment_status_card.dart';
import 'utils/create_order_formatters.dart';

/// Màn đặt đơn thành công + điều hướng theo dõi / danh sách đơn.
class OrderSuccessScreen extends ConsumerWidget {
  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.trackingCode,
    required this.deliveryFee,
    this.distanceKm,
  });

  final String orderId;
  final String trackingCode;
  final double deliveryFee;
  final double? distanceKm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = trackingCode.trim().isEmpty
        ? 'GH-${orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId}'
        : trackingCode;
    final orderAsync = trackingCode.trim().isEmpty
        ? ref.watch(orderByIdProvider(orderId))
        : ref.watch(orderByTrackingCodeProvider(trackingCode));
    final order = orderAsync.valueOrNull;

    if (order != null && order.trackingCode.isNotEmpty) {
      ref.watch(
        trackedOrderRealtimeProvider((
          orderId: order.id,
          trackingCode: order.trackingCode,
        )),
      );
    }
    final hasDriver = order?.driverId?.trim().isNotEmpty == true;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xl3),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 52,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Đặt đơn thành công!',
                style: AppTextStyles.headingLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                hasDriver
                    ? 'Đơn hàng đã có tài xế nhận. Bạn có thể theo dõi hành trình ngay bây giờ.'
                    : 'Đơn đang chờ tài xế nhận. Thời gian tìm tài xế tối đa là 15 phút.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl2),
              if (order != null && order.canWaitForDriver) ...[
                OrderAssignmentStatusCard(
                  order: order,
                  onCancelled: () => context.go('/customer-home?tab=orders'),
                ),
                const SizedBox(height: AppSpacing.xl2),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: AppRadius.lg,
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadow.card,
                ),
                child: Column(
                  children: [
                    Text(
                      'Mã vận đơn',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            code,
                            style: AppTextStyles.headingMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Sao chép',
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: code));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã sao chép mã đơn'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: AppSpacing.xl2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Phí giao hàng',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          formatDeliveryFee(deliveryFee),
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                    if (distanceKm != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Khoảng cách ước tính',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${distanceKm!.toStringAsFixed(1)} km',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl3),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.go(
                      '/customer-home?tab=tracking&code=${Uri.encodeComponent(code)}',
                    );
                  },
                  icon: const Icon(Icons.route_rounded),
                  label: const Text('Theo dõi đơn hàng'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.textOnAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.full),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    context.go('/customer-home?tab=orders');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.full),
                  ),
                  child: const Text('Xem danh sách đơn'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => context.go('/customer-home'),
                child: Text(
                  'Về trang chủ',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
