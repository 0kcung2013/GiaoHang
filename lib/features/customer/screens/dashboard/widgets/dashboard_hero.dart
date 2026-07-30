import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/driver_model.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/providers/customer_providers.dart';

part 'dashboard_hero_components.dart';
part 'dashboard_hero_utils.dart';

class DashboardActiveDeliveryCard extends ConsumerWidget {
  const DashboardActiveDeliveryCard({super.key, required this.activeOrders});

  final List<OrderModel> activeOrders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (activeOrders.isEmpty) {
      return const SizedBox.shrink();
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

class _ActiveDeliveryHero extends StatelessWidget {
  const _ActiveDeliveryHero({required this.order, required this.driver});

  final OrderModel order;
  final DriverModel? driver;

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
  const _MultipleDeliveryHero({
    required this.orders,
    required this.priorityOrder,
    required this.driver,
  });

  final List<OrderModel> orders;
  final OrderModel priorityOrder;
  final DriverModel? driver;

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
                  foregroundColor: AppColors.accent,
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
