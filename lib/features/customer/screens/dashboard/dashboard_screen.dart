import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/providers/customer_providers.dart';
import '../order/order_screen.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_hero.dart';
import 'widgets/dashboard_order_card.dart';
import 'widgets/dashboard_quick_actions.dart';
import 'widgets/dashboard_states.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = Supabase.instance.client.auth.currentUser;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _Layout.fromWidth(constraints.maxWidth);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            layout.padding,
            layout.topPadding,
            layout.padding,
            AppSpacing.xl3,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: layout.maxWidth),
              child: currentUser == null
                  ? const DashboardLoginRequired()
                  : _DashboardBody(user: currentUser, layout: layout),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  final User user;
  final _Layout layout;

  const _DashboardBody({required this.user, required this.layout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ordersRealtimeProvider(user.id));
    final ordersAsync = ref.watch(customerOrdersProvider(user.id));

    if (ordersAsync.isLoading && !ordersAsync.hasValue) {
      return const DashboardShimmer();
    }

    if (ordersAsync.hasError && !ordersAsync.hasValue) {
      return DashboardError(
        onRetry: () => ref.invalidate(customerOrdersProvider(user.id)),
      );
    }

    final allOrders = ordersAsync.valueOrNull ?? const <OrderModel>[];
    final activeOrders = allOrders
        .where((order) => _activeStatuses.contains(order.status))
        .toList();
    final recentOrders = allOrders
        .where((order) => !_activeStatuses.contains(order.status))
        .take(3)
        .toList();

    return AnimatedSwitcher(
      duration: AppDuration.page,
      switchInCurve: AppCurve.decelerate,
      switchOutCurve: AppCurve.accelerate,
      child: Column(
        key: ValueKey('dashboard_${activeOrders.length}_${allOrders.length}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DashboardHeader(),
          SizedBox(height: layout.sectionGap),
          DashboardHero(
            activeOrders: activeOrders,
            isFirstDelivery: allOrders.isEmpty,
          ),
          SizedBox(height: layout.sectionGap),
          DashboardQuickActions(hasActiveDelivery: activeOrders.isNotEmpty),
          if (recentOrders.isNotEmpty) ...[
            SizedBox(height: layout.sectionGap),
            _RecentDeliveries(
              orders: recentOrders,
              customerId: user.id,
              showViewAll: allOrders.length > recentOrders.length,
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentDeliveries extends StatelessWidget {
  final List<OrderModel> orders;
  final String customerId;
  final bool showViewAll;

  const _RecentDeliveries({
    required this.orders,
    required this.customerId,
    required this.showViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Gần đây',
                style: AppTextStyles.headingMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (showViewAll)
              TextButton(
                onPressed: () => context.go('/customer-home?tab=orders'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                ),
                child: const Text('Xem tất cả'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Material(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl2,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < orders.length; index++)
                DashboardOrderCard(
                  order: orders[index],
                  showDivider: index < orders.length - 1,
                  onTap: () => showOrderDetailSheet(
                    context: context,
                    customerId: customerId,
                    order: orders[index],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Layout {
  final double padding;
  final double topPadding;
  final double sectionGap;
  final double maxWidth;

  const _Layout({
    required this.padding,
    required this.topPadding,
    required this.sectionGap,
    required this.maxWidth,
  });

  factory _Layout.fromWidth(double width) {
    if (width >= 1024) {
      return const _Layout(
        padding: AppSpacing.xl3,
        topPadding: AppSpacing.xl2,
        sectionGap: AppSpacing.xl2,
        maxWidth: 600,
      );
    }
    if (width >= 600) {
      return const _Layout(
        padding: AppSpacing.xl3,
        topPadding: AppSpacing.xl2,
        sectionGap: AppSpacing.xl2,
        maxWidth: 520,
      );
    }
    return const _Layout(
      padding: AppSpacing.screenH,
      topPadding: AppSpacing.md,
      sectionGap: AppSpacing.xl2,
      maxWidth: double.infinity,
    );
  }
}

const _activeStatuses = {
  'pending',
  'confirmed',
  'assigned',
  'picking_up',
  'delivering',
};
