import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/driver_model.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/providers/customer_providers.dart';

part 'dashboard_hero_components.dart';
part 'dashboard_hero_utils.dart';

class DashboardHero extends ConsumerWidget {
  final List<OrderModel> activeOrders;
  final bool isFirstDelivery;

  const DashboardHero({
    super.key,
    required this.activeOrders,
    required this.isFirstDelivery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (activeOrders.isEmpty) {
      return _CreateDeliveryHero(isFirstDelivery: isFirstDelivery);
    }

    final ordered = [...activeOrders]..sort(_compareActiveOrders);
    final priorityOrder = ordered.first;
    final driverAsync = ref.watch(assignedDriverProvider(priorityOrder.id));
    final driver = driverAsync.valueOrNull;

    if (ordered.length == 1) {
      return _ActiveDeliveryHero(order: priorityOrder, driver: driver);
    }

    return _MultipleDeliveryHero(
      orders: ordered,
      priorityOrder: priorityOrder,
      driver: driver,
    );
  }
}

class _CreateDeliveryHero extends StatelessWidget {
  final bool isFirstDelivery;

  const _CreateDeliveryHero({required this.isFirstDelivery});

  @override
  Widget build(BuildContext context) {
    return _HeroSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Eyebrow(
            icon: Icons.local_shipping_rounded,
            label: 'Giao hàng tận nơi',
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            isFirstDelivery
                ? 'Tạo chuyến giao đầu tiên'
                : 'Bạn muốn gửi hàng đi đâu?',
            style: AppTextStyles.displayMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Chọn điểm lấy và điểm giao. Phí vận chuyển được hiển thị trước khi xác nhận.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _EmptyRouteCue(),
          const SizedBox(height: AppSpacing.xl2),
          _PrimaryHeroButton(
            icon: Icons.add_rounded,
            label: 'Tạo chuyến giao',
            onTap: () => context.push('/customer/create-order'),
          ),
          if (isFirstDelivery) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Bạn chỉ thanh toán sau khi xem và đồng ý với mức phí.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveDeliveryHero extends StatelessWidget {
  final OrderModel order;
  final DriverModel? driver;

  const _ActiveDeliveryHero({required this.order, required this.driver});

  @override
  Widget build(BuildContext context) {
    final eta = _etaText(order);
    final expectedTime = _expectedTime(order);

    return _HeroSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Eyebrow(
                  icon: Icons.radio_button_checked_rounded,
                  label: _statusLabel(order.status),
                ),
              ),
              Text(
                _orderCode(order),
                style: AppTextStyles.mono.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  eta ?? _statusTitle(order.status),
                  style: AppTextStyles.displayLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: eta == null ? 25 : 34,
                    height: 1.08,
                    letterSpacing: -0.7,
                  ),
                ),
              ),
              if (expectedTime != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    'Dự kiến $expectedTime',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _RouteSummary(order: order),
          const SizedBox(height: AppSpacing.xl),
          _DeliveryProgress(status: order.status),
          const SizedBox(height: AppSpacing.xl),
          _DriverSummary(driver: driver, hasDriver: order.driverId != null),
          const SizedBox(height: AppSpacing.xl2),
          _PrimaryHeroButton(
            icon: Icons.near_me_rounded,
            label: 'Theo dõi trực tiếp',
            onTap: () => _openTracking(context, order),
          ),
        ],
      ),
    );
  }
}

class _MultipleDeliveryHero extends StatelessWidget {
  final List<OrderModel> orders;
  final OrderModel priorityOrder;
  final DriverModel? driver;

  const _MultipleDeliveryHero({
    required this.orders,
    required this.priorityOrder,
    required this.driver,
  });

  @override
  Widget build(BuildContext context) {
    final eta = _etaText(priorityOrder);

    return _HeroSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${orders.length} chuyến đang hoạt động',
                  style: AppTextStyles.headingMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/customer-home?tab=orders'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  minimumSize: const Size(48, 48),
                ),
                child: const Text('Xem tất cả'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _Eyebrow(
            icon: Icons.bolt_rounded,
            label: 'Cần chú ý tiếp theo',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            priorityOrder.deliveryAddress,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.headingLarge.copyWith(
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            eta == null
                ? _statusTitle(priorityOrder.status)
                : '$eta · ${_statusLabel(priorityOrder.status)}',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _DeliveryProgress(status: priorityOrder.status),
          const SizedBox(height: AppSpacing.lg),
          _DriverSummary(
            driver: driver,
            hasDriver: priorityOrder.driverId != null,
            compact: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '${orders.length - 1} chuyến khác đang được xử lý',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl2),
          _PrimaryHeroButton(
            icon: Icons.near_me_rounded,
            label: 'Theo dõi đơn này',
            onTap: () => _openTracking(context, priorityOrder),
          ),
        ],
      ),
    );
  }
}
