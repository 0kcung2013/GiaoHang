import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/providers/customer_providers.dart';
import 'availability_status_card.dart';
import 'driver_home_layout.dart';
import 'driver_orders_section.dart';
import 'driver_profile_summary.dart';
import 'driver_state_widgets.dart';
import 'driver_stats_grid.dart';
import 'quick_actions_row.dart';

/// Resolves [driverByUserIdProvider] then delegates to [_DriverDataBody].
class DriverDashboardBody extends ConsumerWidget {
  final String userId;
  final DriverHomeLayout layout;

  const DriverDashboardBody({
    super.key,
    required this.userId,
    required this.layout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverAsync = ref.watch(driverByUserIdProvider(userId));
    final availableOrdersAsync = ref.watch(availableOrdersProvider);

    return driverAsync.when(
      loading: () => const DriverLoadingState(),
      error: (_, _) => DriverErrorState(
        onRetry: () {
          ref.invalidate(driverByUserIdProvider(userId));
          ref.invalidate(availableOrdersProvider);
        },
      ),
      data: (driver) {
        if (driver == null) {
          return const MissingDriverProfileState();
        }

        ref.watch(driverHomeOrdersRealtimeProvider(driver.userId));
        final driverOrdersAsync = ref.watch(
          driverOrdersProvider(driver.userId),
        );
        final availableOrdersValue = availableOrdersAsync.valueOrNull;
        final driverOrdersValue = driverOrdersAsync.valueOrNull;
        final isInitialLoading =
            (availableOrdersAsync.isLoading && availableOrdersValue == null) ||
            (driverOrdersAsync.isLoading && driverOrdersValue == null);
        final hasBlockingError =
            (availableOrdersAsync.hasError && availableOrdersValue == null) ||
            (driverOrdersAsync.hasError && driverOrdersValue == null);
        final isRefreshing =
            availableOrdersAsync.isLoading || driverOrdersAsync.isLoading;

        if (isInitialLoading) return const DriverLoadingState();

        if (hasBlockingError) {
          return DriverErrorState(
            onRetry: () {
              ref.invalidate(availableOrdersProvider);
              ref.invalidate(driverOrdersProvider(driver.userId));
            },
          );
        }

        final availableOrders = availableOrdersValue ?? const <OrderModel>[];
        final driverOrders = driverOrdersValue ?? const <OrderModel>[];
        final stats = DriverStats.fromOrders(
          driver: driver,
          availableOrders: availableOrders,
          driverOrders: driverOrders,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DriverProfileSummary(driver: driver),
            SizedBox(height: layout.sectionGap),
            AvailabilityStatusCard(
              driver: driver,
              availableCount: availableOrders.length,
              activeCount: stats.activeDeliveries,
            ),
            SizedBox(height: layout.sectionGap),
            DriverStatsGrid(stats: stats),
            SizedBox(height: layout.sectionGap),
            QuickActionsRow(
              onRefresh: () {
                ref.invalidate(availableOrdersProvider);
                ref.invalidate(driverOrdersProvider(driver.userId));
              },
            ),
            if (isRefreshing) ...[
              const SizedBox(height: AppSpacing.md),
              const _DriverInlineRefreshIndicator(),
            ],
            SizedBox(height: layout.sectionGap),
            DriverOrdersSection(
              title: 'Đơn có thể nhận',
              subtitle: 'Đơn chưa có tài xế và đang chờ xử lý',
              orders: availableOrders,
              emptyTitle: 'Không có đơn phù hợp',
              emptyMessage: 'Hiện chưa có đơn mới phù hợp để nhận.',
              acceptDriverId: driver.userId,
            ),
            SizedBox(height: layout.sectionGap),
            DriverOrdersSection(
              title: 'Đơn của bạn',
              subtitle: 'Các đơn đã được phân công cho tài xế',
              orders: driverOrders,
              emptyTitle: 'Chưa có đơn được phân công',
              emptyMessage:
                  'Khi có đơn thuộc tài xế này, đơn sẽ xuất hiện ở đây.',
            ),
          ],
        );
      },
    );
  }
}

class _DriverInlineRefreshIndicator extends StatelessWidget {
  const _DriverInlineRefreshIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Đang cập nhật đơn hàng...',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
