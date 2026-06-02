import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/providers/customer_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = Supabase.instance.client.auth.currentUser;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _DashboardLayout.fromWidth(constraints.maxWidth);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            layout.horizontalPadding,
            layout.topPadding,
            layout.horizontalPadding,
            AppSpacing.xl2,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
              child: currentUser == null
                  ? const _DashboardMessageState(
                      icon: Icons.lock_outline_rounded,
                      title: 'Cần đăng nhập',
                      message: 'Vui lòng đăng nhập để xem tổng quan đơn hàng.',
                    )
                  : _DashboardDataBody(user: currentUser, layout: layout),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardDataBody extends ConsumerWidget {
  final User user;
  final _DashboardLayout layout;

  const _DashboardDataBody({required this.user, required this.layout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(customerProfileProvider(user.id));
    final ordersAsync = ref.watch(customerOrdersProvider(user.id));
    final recentOrdersAsync = ref.watch(recentOrdersProvider(user.id));
    final activeOrderAsync = ref.watch(activeOrderProvider(user.id));
    final unreadCountAsync = ref.watch(
      unreadNotificationCountProvider(user.id),
    );
    final asyncValues = [
      profileAsync,
      ordersAsync,
      recentOrdersAsync,
      activeOrderAsync,
      unreadCountAsync,
    ];

    if (asyncValues.any((value) => value.isLoading && !value.hasValue)) {
      return const _DashboardLoadingState();
    }

    final hasError = asyncValues.any(
      (value) => value.hasError && !value.hasValue,
    );
    if (hasError) {
      return _DashboardErrorState(
        onRetry: () {
          ref.invalidate(customerProfileProvider(user.id));
          ref.invalidate(customerOrdersProvider(user.id));
          ref.invalidate(recentOrdersProvider(user.id));
          ref.invalidate(activeOrderProvider(user.id));
          ref.invalidate(unreadNotificationCountProvider(user.id));
        },
      );
    }

    final profile = profileAsync.valueOrNull;
    final allOrders = ordersAsync.valueOrNull ?? const <OrderModel>[];
    final recentOrders = recentOrdersAsync.valueOrNull ?? const <OrderModel>[];
    final activeOrder = activeOrderAsync.valueOrNull;
    final unreadCount = unreadCountAsync.valueOrNull ?? 0;
    final name = _displayName(user, profile?.fullName);
    final stats = _DashboardStats.fromOrders(allOrders, unreadCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderSection(
          name: name,
          activeCount: stats.activeOrders,
          activeOrder: activeOrder,
          unreadNotificationCount: unreadCount,
        ),
        SizedBox(height: layout.sectionGap),
        _SummaryGrid(stats: stats),
        SizedBox(height: layout.sectionGap),
        _RecentOrdersSection(orders: recentOrders),
      ],
    );
  }
}

class _DashboardLayout {
  static const tabletBreakpoint = 600.0;
  static const desktopBreakpoint = 1024.0;
  static const tabletContentMaxWidth = 900.0;
  static const desktopContentMaxWidth = 1040.0;
  static const wideStatsMinWidth = 760.0;
  static const recentOrdersMaxWidth = 820.0;

  final double horizontalPadding;
  final double topPadding;
  final double sectionGap;
  final double maxContentWidth;

  const _DashboardLayout({
    required this.horizontalPadding,
    required this.topPadding,
    required this.sectionGap,
    required this.maxContentWidth,
  });

  factory _DashboardLayout.fromWidth(double width) {
    if (width > desktopBreakpoint) {
      return const _DashboardLayout(
        horizontalPadding: AppSpacing.xl3,
        topPadding: AppSpacing.xl3,
        sectionGap: AppSpacing.xl3,
        maxContentWidth: desktopContentMaxWidth,
      );
    }

    if (width >= tabletBreakpoint) {
      return const _DashboardLayout(
        horizontalPadding: AppSpacing.xl3,
        topPadding: AppSpacing.xl3,
        sectionGap: AppSpacing.xl2,
        maxContentWidth: tabletContentMaxWidth,
      );
    }

    return const _DashboardLayout(
      horizontalPadding: AppSpacing.screenH,
      topPadding: AppSpacing.xl2,
      sectionGap: AppSpacing.xl2,
      maxContentWidth: double.infinity,
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final String name;
  final int activeCount;
  final OrderModel? activeOrder;
  final int unreadNotificationCount;

  const _HeaderSection({
    required this.name,
    required this.activeCount,
    required this.activeOrder,
    required this.unreadNotificationCount,
  });

  @override
  Widget build(BuildContext context) {
    final activeText = activeCount == 0
        ? 'Bạn chưa có đơn đang xử lý'
        : 'Bạn có $activeCount đơn đang xử lý';
    final chipText = activeOrder == null
        ? 'Sẵn sàng tạo đơn mới'
        : '${_displayOrderCode(activeOrder!)} cần theo dõi';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.xl,
        boxShadow: AppShadow.elevated,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào, $name!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headingLarge.copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  unreadNotificationCount > 0
                      ? '$activeText · $unreadNotificationCount thông báo mới'
                      : activeText,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.16),
                    borderRadius: AppRadius.full,
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    chipText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textOnDark,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Material(
                      color: AppColors.accent,
                      borderRadius: AppRadius.full,
                      child: InkWell(
                        onTap: () => context.push('/customer/create-order'),
                        borderRadius: AppRadius.full,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.add_rounded,
                                color: AppColors.textOnAccent,
                                size: 18,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Flexible(
                                child: Text(
                                  'Tạo đơn hàng mới',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textOnAccent,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.textOnDark.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.textOnDark.withValues(alpha: 0.24),
              ),
            ),
            child: Center(
              child: Text(
                _getInitials(name),
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textOnDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String fullName) {
    final names = fullName.trim().split(RegExp(r'\s+'));
    if (names.length >= 2) {
      return '${names[names.length - 2][0]}${names[names.length - 1][0]}'
          .toUpperCase();
    }
    return fullName.isNotEmpty ? fullName.substring(0, 1).toUpperCase() : 'KH';
  }
}

class _SummaryGrid extends StatelessWidget {
  final _DashboardStats stats;

  const _SummaryGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            constraints.maxWidth >= _DashboardLayout.wideStatsMinWidth ? 4 : 2;

        return GridView(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisExtent: 82,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _SummaryCard(
              value: stats.totalOrders.toString(),
              label: 'Tổng đơn',
              icon: Icons.inventory_2_rounded,
              color: AppColors.info,
            ),
            _SummaryCard(
              value: stats.activeOrders.toString(),
              label: 'Đơn đang xử lý',
              icon: Icons.local_shipping_rounded,
              color: AppColors.accent,
            ),
            _SummaryCard(
              value: stats.completedOrders.toString(),
              label: 'Đã hoàn thành',
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
            ),
            _SummaryCard(
              value: stats.unreadNotifications.toString(),
              label: 'Thông báo mới',
              icon: Icons.notifications_rounded,
              color: AppColors.warning,
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.lg,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.lg,
          border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
          boxShadow: AppShadow.subtle,
        ),
        child: Row(
          children: [
            Container(width: 4, color: color),
            Expanded(
              child: Container(
                color: color.withValues(alpha: 0.035),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: AppRadius.md,
                            ),
                            child: Icon(icon, color: color, size: 18),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              label,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                letterSpacing: 0,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      value,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headingLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentOrdersSection extends StatelessWidget {
  final List<OrderModel> orders;

  const _RecentOrdersSection({required this.orders});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            constraints.maxWidth >= _DashboardLayout.wideStatsMinWidth
            ? _DashboardLayout.recentOrdersMaxWidth
            : double.infinity;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đơn gần đây',
                            style: AppTextStyles.headingSmall.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Cập nhật trạng thái mới nhất',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: AppRadius.full,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: AppRadius.full,
                          onTap: () {},
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            child: Text(
                              'Xem tất cả',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (orders.isEmpty)
                  const _RecentOrdersEmptyState()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm + 2),
                    itemBuilder: (context, i) {
                      return _RecentOrderCard(order: orders[i]);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RecentOrderCard extends StatelessWidget {
  final OrderModel order;

  const _RecentOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppShadow.card,
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: AppRadius.full,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _statusIcon(order.status),
              color: statusColor,
              size: 21,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _displayOrderCode(order),
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  order.deliveryAddress,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.full,
      ),
      child: Text(
        _statusLabel(status),
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _RecentOrdersEmptyState extends StatelessWidget {
  const _RecentOrdersEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl2),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: AppRadius.lg,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Chưa có đơn hàng',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Các đơn bạn tạo sẽ xuất hiện tại đây.',
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

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _LoadingBlock(height: 188),
        SizedBox(height: AppSpacing.xl2),
        _LoadingBlock(height: 260),
        SizedBox(height: AppSpacing.xl2),
        _LoadingBlock(height: 180),
      ],
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  final double height;

  const _LoadingBlock({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _DashboardErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _DashboardMessageState(
      icon: Icons.error_outline_rounded,
      title: 'Không tải được dashboard',
      message: 'Vui lòng kiểm tra kết nối và thử lại.',
      actionLabel: 'Thử lại',
      onAction: onRetry,
      color: AppColors.error,
    );
  }
}

class _DashboardMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color color;

  const _DashboardMessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.color = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl2),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.lg,
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _StateActionButton(label: actionLabel!, onTap: onAction!),
          ],
        ],
      ),
    );
  }
}

class _StateActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _StateActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent,
      borderRadius: AppRadius.full,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.full,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textOnAccent,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardStats {
  final int totalOrders;
  final int activeOrders;
  final int completedOrders;
  final int unreadNotifications;

  const _DashboardStats({
    required this.totalOrders,
    required this.activeOrders,
    required this.completedOrders,
    required this.unreadNotifications,
  });

  factory _DashboardStats.fromOrders(
    List<OrderModel> orders,
    int unreadNotifications,
  ) {
    return _DashboardStats(
      totalOrders: orders.length,
      activeOrders: orders
          .where((order) => _activeStatuses.contains(order.status))
          .length,
      completedOrders: orders
          .where((order) => order.status == 'delivered')
          .length,
      unreadNotifications: unreadNotifications,
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

String _displayOrderCode(OrderModel order) {
  if (order.trackingCode.isNotEmpty) return order.trackingCode;
  final length = order.id.length >= 8 ? 8 : order.id.length;
  return '#${order.id.substring(0, length)}';
}

String _statusLabel(String status) {
  return switch (status) {
    'pending' => 'Chờ xác nhận',
    'confirmed' => 'Đã xác nhận',
    'assigned' => 'Tài xế đã nhận đơn',
    'picking_up' => 'Tài xế đang đến lấy hàng',
    'delivering' => 'Đang giao hàng',
    'delivered' => 'Giao hàng thành công',
    'cancelled' => 'Huỷ',
    _ => 'Không rõ',
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'pending' => AppColors.warning,
    'confirmed' => AppColors.info,
    'assigned' => AppColors.info,
    'picking_up' => AppColors.accent,
    'delivering' => AppColors.accent,
    'delivered' => AppColors.success,
    'cancelled' => AppColors.error,
    _ => AppColors.textMuted,
  };
}

IconData _statusIcon(String status) {
  return switch (status) {
    'pending' => Icons.access_time_rounded,
    'confirmed' => Icons.check_circle_outline_rounded,
    'assigned' => Icons.local_shipping_rounded,
    'picking_up' => Icons.inventory_2_rounded,
    'delivering' => Icons.local_shipping_outlined,
    'delivered' => Icons.check_circle_rounded,
    'cancelled' => Icons.cancel_rounded,
    _ => Icons.help_outline_rounded,
  };
}

const Set<String> _activeStatuses = {
  'pending',
  'confirmed',
  'assigned',
  'picking_up',
  'delivering',
};
