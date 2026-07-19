import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/providers/customer_providers.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_order_card.dart';
import 'widgets/dashboard_states.dart';
import 'widgets/dashboard_stats.dart';

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
            AppSpacing.xl2,
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
    final profileAsync = ref.watch(customerProfileProvider(user.id));
    final ordersAsync = ref.watch(customerOrdersProvider(user.id));
    final activeOrderAsync = ref.watch(activeOrderProvider(user.id));

    final isLoading = profileAsync.isLoading ||
        ordersAsync.isLoading && !ordersAsync.hasValue;
    if (isLoading) return const DashboardShimmer();

    final hasError =
        (profileAsync.hasError && !profileAsync.hasValue) ||
        (ordersAsync.hasError && !ordersAsync.hasValue);
    if (hasError) {
      return DashboardError(
        onRetry: () {
          ref.invalidate(customerProfileProvider(user.id));
          ref.invalidate(customerOrdersProvider(user.id));
        },
      );
    }

    final profile = profileAsync.valueOrNull;
    final allOrders = ordersAsync.valueOrNull ?? const <OrderModel>[];
    final activeOrder = activeOrderAsync.valueOrNull;
    final name = _displayName(user, profile?.fullName);
    final activeCount =
        allOrders.where((o) => _activeStatuses.contains(o.status)).length;
    final completedCount =
        allOrders.where((o) => o.status == 'delivered').length;
    final recentOrders = allOrders.take(3).toList();

    return AnimatedSwitcher(
      duration: AppDuration.page,
      switchInCurve: AppCurve.decelerate,
      switchOutCurve: AppCurve.accelerate,
      child: Column(
        key: ValueKey('body_${allOrders.length}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardHeader(
            userName: name,
            activeCount: activeCount,
            hasActiveDelivery: activeOrder != null,
          ),
          SizedBox(height: layout.sectionGap),
          DashboardStats(
            activeCount: activeCount,
            completedCount: completedCount,
          ),
          SizedBox(height: layout.sectionGap),
          _buildRecentOrdersHeader(context, allOrders),
          const SizedBox(height: AppSpacing.md),
          if (recentOrders.isEmpty)
            const DashboardEmpty()
          else
            ...recentOrders.map(
              (order) => DashboardOrderCard(order: order),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentOrdersHeader(
    BuildContext context,
    List<OrderModel> allOrders,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Đơn gần đây',
          style: AppTextStyles.headingLarge.copyWith(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (allOrders.length > 3)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {},
              borderRadius: AppRadius.full,
              splashColor: AppColors.accent.withValues(alpha: 0.08),
              highlightColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  'Xem tất cả',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
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
        topPadding: AppSpacing.xl3,
        sectionGap: AppSpacing.xl2,
        maxWidth: 600,
      );
    }
    if (width >= 600) {
      return const _Layout(
        padding: AppSpacing.xl3,
        topPadding: AppSpacing.xl3,
        sectionGap: AppSpacing.xl2,
        maxWidth: 520,
      );
    }
    return const _Layout(
      padding: AppSpacing.screenH,
      topPadding: AppSpacing.xl2,
      sectionGap: AppSpacing.xl2,
      maxWidth: double.infinity,
    );
  }
}

String _displayName(User user, String? profileName) {
  final metadataName =
      user.userMetadata?['full_name']?.toString() ??
      user.userMetadata?['name']?.toString();
  final name = (profileName?.trim().isNotEmpty ?? false)
      ? profileName!.trim()
      : metadataName?.trim();
  if (name != null && name.isNotEmpty) return name;
  if ((user.email ?? '').isNotEmpty) return user.email!.split('@').first;
  return 'Khách hàng';
}

const _activeStatuses = {
  'pending',
  'confirmed',
  'assigned',
  'picking_up',
  'delivering',
};
