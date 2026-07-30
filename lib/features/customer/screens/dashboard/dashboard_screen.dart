import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/providers/customer_providers.dart';
import 'widgets/dashboard_create_delivery_hero.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_hero.dart';
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
  const _DashboardBody({required this.user, required this.layout});

  final User user;
  final _Layout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ordersRealtimeProvider(user.id));
    final ordersAsync = ref.watch(customerOrdersProvider(user.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardHeader(user: user),
        SizedBox(height: layout.sectionGap),
        if (ordersAsync.isLoading && !ordersAsync.hasValue)
          const DashboardShimmer()
        else if (ordersAsync.hasError && !ordersAsync.hasValue)
          DashboardError(
            onRetry: () => ref.invalidate(customerOrdersProvider(user.id)),
          )
        else
          _DashboardContent(
            allOrders: ordersAsync.valueOrNull ?? const <OrderModel>[],
            sectionGap: layout.sectionGap,
          ),
      ],
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.allOrders, required this.sectionGap});

  final List<OrderModel> allOrders;
  final double sectionGap;

  @override
  Widget build(BuildContext context) {
    final activeOrders = allOrders
        .where((order) => _activeStatuses.contains(order.status))
        .toList();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : AppDuration.page,
      switchInCurve: AppCurve.decelerate,
      switchOutCurve: AppCurve.accelerate,
      child: Column(
        key: ValueKey('dashboard_${activeOrders.length}_${allOrders.length}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardCreateDeliveryHero(isFirstDelivery: allOrders.isEmpty),
          SizedBox(height: sectionGap),
          DashboardQuickActions(hasActiveDelivery: activeOrders.isNotEmpty),
          if (activeOrders.isNotEmpty) ...[
            SizedBox(height: sectionGap),
            DashboardActiveDeliveryCard(activeOrders: activeOrders),
          ],
        ],
      ),
    );
  }
}

class _Layout {
  const _Layout({
    required this.padding,
    required this.topPadding,
    required this.sectionGap,
    required this.maxWidth,
  });

  final double padding;
  final double topPadding;
  final double sectionGap;
  final double maxWidth;

  factory _Layout.fromWidth(double width) {
    if (width >= 1024) {
      return const _Layout(
        padding: AppSpacing.xl3,
        topPadding: AppSpacing.xl2,
        sectionGap: AppSpacing.xl2,
        maxWidth: 680,
      );
    }
    if (width >= 600) {
      return const _Layout(
        padding: AppSpacing.xl3,
        topPadding: AppSpacing.xl2,
        sectionGap: AppSpacing.xl2,
        maxWidth: 600,
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
