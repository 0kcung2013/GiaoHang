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
                  ? const _MessageState(
                      icon: Icons.lock_outline_rounded,
                      title: 'Cần đăng nhập',
                      message: 'Vui lòng đăng nhập để xem tổng quan.',
                    )
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
    if (isLoading) return const _LoadingState();

    final hasError =
        (profileAsync.hasError && !profileAsync.hasValue) ||
        (ordersAsync.hasError && !ordersAsync.hasValue);
    if (hasError) {
      return _MessageState(
        icon: Icons.error_outline_rounded,
        title: 'Lỗi tải dữ liệu',
        message: 'Kiểm tra kết nối và thử lại.',
        actionLabel: 'Thử lại',
        onAction: () {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xin chào, $name!',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.headingMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activeOrder != null
                        ? '${_displayOrderCode(activeOrder)} đang xử lý'
                        : 'Sẵn sàng tạo đơn mới',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Material(
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
                      Text(
                        'Tạo đơn',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textOnAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: layout.sectionGap),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: activeCount.toString(),
                label: 'Đang xử lý',
                icon: Icons.local_shipping_rounded,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(
                value: completedCount.toString(),
                label: 'Hoàn thành',
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        SizedBox(height: layout.sectionGap),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Đơn gần đây',
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            if (allOrders.length > 3)
              GestureDetector(
                onTap: () {},
                child: Text(
                  'Xem tất cả',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (recentOrders.isEmpty)
          const _EmptyState()
        else
          ...recentOrders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _OrderCard(order: order),
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: AppShadow.subtle,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.md,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTextStyles.headingMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(order.status);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppRadius.full,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_statusIcon(order.status), color: color, size: 18),
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
                    _StatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  order.deliveryAddress,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.full,
      ),
      child: Text(
        _statusLabel(status),
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl2),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            color: AppColors.textMuted,
            size: 32,
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
            'Tạo đơn đầu tiên để bắt đầu.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: AppRadius.lg,
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl2),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
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
            Material(
              color: AppColors.accent,
              borderRadius: AppRadius.full,
              child: InkWell(
                onTap: onAction,
                borderRadius: AppRadius.full,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.sm,
                  ),
                  child: Text(
                    actionLabel!,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textOnAccent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
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

// ── Helpers ──────────────────────────────────────────────────────────────────

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
  final len = order.id.length >= 8 ? 8 : order.id.length;
  return '#${order.id.substring(0, len)}';
}

String _statusLabel(String status) {
  return switch (status) {
    'pending' => 'Chờ xác nhận',
    'confirmed' => 'Đã xác nhận',
    'assigned' => 'Đã phân công',
    'picking_up' => 'Đang lấy',
    'delivering' => 'Đang giao',
    'delivered' => 'Hoàn thành',
    'cancelled' => 'Đã huỷ',
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
    'picking_up' => Icons.storefront_rounded,
    'delivering' => Icons.local_shipping_outlined,
    'delivered' => Icons.check_circle_rounded,
    'cancelled' => Icons.cancel_rounded,
    _ => Icons.help_outline_rounded,
  };
}

const _activeStatuses = {
  'pending',
  'confirmed',
  'assigned',
  'picking_up',
  'delivering',
};
