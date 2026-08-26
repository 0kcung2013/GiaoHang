import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../../home/widgets/driver_order_card.dart';
import '../utils/driver_order_filter.dart';

class DriverOrdersList extends StatelessWidget {
  final DriverOrderFilter filter;
  final List<OrderModel> orders;
  final String? acceptDriverId;
  final Widget? header;
  final EdgeInsets contentPadding;
  final double maxContentWidth;

  const DriverOrdersList({
    super.key,
    required this.filter,
    required this.orders,
    this.acceptDriverId,
    this.header,
    this.contentPadding = EdgeInsets.zero,
    this.maxContentWidth = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: PageStorageKey('driver-orders-${filter.name}'),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        if (header != null)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              contentPadding.left,
              contentPadding.top,
              contentPadding.right,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: _constrain(RepaintBoundary(child: header!)),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            contentPadding.left,
            header == null ? contentPadding.top : AppSpacing.xl,
            contentPadding.right,
            0,
          ),
          sliver: SliverToBoxAdapter(child: _constrain(_sectionHeader())),
        ),
        if (orders.isEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              contentPadding.left,
              AppSpacing.md,
              contentPadding.right,
              contentPadding.bottom,
            ),
            sliver: SliverToBoxAdapter(
              child: _constrain(_EmptyOrdersState(filter: filter)),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              contentPadding.left,
              AppSpacing.md,
              contentPadding.right,
              contentPadding.bottom,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _constrain(
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: DriverOrderCard(
                      order: orders[index],
                      acceptDriverId: acceptDriverId,
                    ),
                  ),
                ),
                childCount: orders.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _sectionHeader() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: AppRadius.md,
          ),
          child: Icon(filter.icon, color: AppColors.info, size: 19),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            filter.title,
            style: AppTextStyles.headingSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _CountPill(count: orders.length),
      ],
    );
  }

  Widget _constrain(Widget child) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final int count;

  const _CountPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: AppRadius.full,
      ),
      child: Text(
        count.toString(),
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.info,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _EmptyOrdersState extends StatelessWidget {
  final DriverOrderFilter filter;

  const _EmptyOrdersState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl2,
        vertical: AppSpacing.xl3,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: AppRadius.xl,
            ),
            child: Icon(filter.icon, color: AppColors.info, size: 28),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            filter.emptyTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            filter.emptyMessage,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
