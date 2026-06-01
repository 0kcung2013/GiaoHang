import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/driver_model.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/providers/customer_providers.dart';

class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text(
          'DATN - Tài xế',
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: AppColors.bgCard,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = _DriverHomeLayout.fromWidth(constraints.maxWidth);

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
                      ? const _DriverMessageState(
                          icon: Icons.lock_outline_rounded,
                          title: 'Cần đăng nhập',
                          message:
                              'Vui lòng đăng nhập bằng tài khoản tài xế để xem đơn hàng.',
                        )
                      : _DriverDashboardBody(
                          userId: currentUser.id,
                          layout: layout,
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DriverDashboardBody extends ConsumerWidget {
  final String userId;
  final _DriverHomeLayout layout;

  const _DriverDashboardBody({required this.userId, required this.layout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverAsync = ref.watch(driverByUserIdProvider(userId));
    final availableOrdersAsync = ref.watch(availableOrdersProvider);

    return driverAsync.when(
      loading: () => const _DriverLoadingState(),
      error: (_, _) => _DriverErrorState(
        onRetry: () {
          ref.invalidate(driverByUserIdProvider(userId));
          ref.invalidate(availableOrdersProvider);
        },
      ),
      data: (driver) {
        if (driver == null) {
          return const _MissingDriverProfileState();
        }

        final driverOrdersAsync = ref.watch(driverOrdersProvider(driver.userId));
        final isLoading =
            availableOrdersAsync.isLoading || driverOrdersAsync.isLoading;
        final hasError =
            availableOrdersAsync.hasError || driverOrdersAsync.hasError;

        if (isLoading) return const _DriverLoadingState();

        if (hasError) {
          return _DriverErrorState(
            onRetry: () {
              ref.invalidate(availableOrdersProvider);
              ref.invalidate(driverOrdersProvider(driver.userId));
            },
          );
        }

        final availableOrders =
            availableOrdersAsync.valueOrNull ?? const <OrderModel>[];
        final driverOrders =
            driverOrdersAsync.valueOrNull ?? const <OrderModel>[];
        final stats = _DriverStats.fromOrders(
          driver: driver,
          availableOrders: availableOrders,
          driverOrders: driverOrders,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DriverProfileSummary(driver: driver),
            SizedBox(height: layout.sectionGap),
            _AvailabilityStatusCard(
              driver: driver,
              availableCount: availableOrders.length,
              activeCount: stats.activeDeliveries,
            ),
            SizedBox(height: layout.sectionGap),
            _DriverStatsGrid(stats: stats),
            SizedBox(height: layout.sectionGap),
            _QuickActionsRow(
              onRefresh: () {
                ref.invalidate(availableOrdersProvider);
                ref.invalidate(driverOrdersProvider(driver.userId));
              },
            ),
            SizedBox(height: layout.sectionGap),
            _DriverOrdersSection(
              title: 'Đơn có thể nhận',
              subtitle: 'Đơn chưa có tài xế và đang chờ xử lý',
              orders: availableOrders,
              emptyTitle: 'Không có đơn phù hợp',
              emptyMessage: 'Hiện chưa có đơn mới phù hợp để nhận.',
              acceptDriverId: driver.userId,
            ),
            SizedBox(height: layout.sectionGap),
            _DriverOrdersSection(
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

class _DriverHomeLayout {
  static const tabletBreakpoint = 600.0;
  static const desktopBreakpoint = 1024.0;
  static const wideStatsMinWidth = 760.0;

  final double horizontalPadding;
  final double topPadding;
  final double sectionGap;
  final double maxContentWidth;

  const _DriverHomeLayout({
    required this.horizontalPadding,
    required this.topPadding,
    required this.sectionGap,
    required this.maxContentWidth,
  });

  factory _DriverHomeLayout.fromWidth(double width) {
    if (width >= desktopBreakpoint) {
      return const _DriverHomeLayout(
        horizontalPadding: AppSpacing.xl3,
        topPadding: AppSpacing.xl3,
        sectionGap: AppSpacing.xl3,
        maxContentWidth: 1040,
      );
    }

    if (width >= tabletBreakpoint) {
      return const _DriverHomeLayout(
        horizontalPadding: AppSpacing.xl3,
        topPadding: AppSpacing.xl3,
        sectionGap: AppSpacing.xl2,
        maxContentWidth: 860,
      );
    }

    return const _DriverHomeLayout(
      horizontalPadding: AppSpacing.screenH,
      topPadding: AppSpacing.xl2,
      sectionGap: AppSpacing.xl2,
      maxContentWidth: double.infinity,
    );
  }
}

class _DriverProfileSummary extends StatelessWidget {
  final DriverModel driver;

  const _DriverProfileSummary({required this.driver});

  @override
  Widget build(BuildContext context) {
    final vehicle = _joinNonEmpty([driver.vehicleType, driver.licensePlate]);
    final rating = driver.rating == null
        ? 'Chưa có đánh giá'
        : '${driver.rating!.toStringAsFixed(1)} điểm';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.xl,
        boxShadow: AppShadow.elevated,
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.18),
              borderRadius: AppRadius.lg,
              border: Border.all(color: AppColors.info.withValues(alpha: 0.28)),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: AppColors.textOnDark,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bảng điều khiển tài xế',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headingLarge.copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  vehicle.isEmpty ? 'Hồ sơ tài xế đã kết nối' : vehicle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _HeaderChip(label: rating, icon: Icons.star_rounded),
                    _HeaderChip(
                      label: '${driver.totalDeliveries} chuyến đã giao',
                      icon: Icons.check_circle_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _HeaderChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.16),
        borderRadius: AppRadius.full,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textOnDark, size: 14),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textOnDark,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityStatusCard extends StatelessWidget {
  final DriverModel driver;
  final int availableCount;
  final int activeCount;

  const _AvailabilityStatusCard({
    required this.driver,
    required this.availableCount,
    required this.activeCount,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = driver.isAvailable;
    final color = isAvailable ? AppColors.success : AppColors.error;

    return _SectionCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppRadius.lg,
              ),
              child: Icon(
                isAvailable
                    ? Icons.radio_button_checked_rounded
                    : Icons.pause_circle_filled_rounded,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAvailable
                        ? 'Đang sẵn sàng nhận đơn'
                        : 'Đang tạm nghỉ',
                    style: AppTextStyles.headingSmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    isAvailable
                        ? 'Có $availableCount đơn mới và $activeCount đơn đang xử lý.'
                        : 'Bật trạng thái sẵn sàng trong hồ sơ tài xế để nhận đơn mới.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverStatsGrid extends StatelessWidget {
  final _DriverStats stats;

  const _DriverStatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            constraints.maxWidth >= _DriverHomeLayout.wideStatsMinWidth ? 4 : 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: crossAxisCount == 4 ? 1.28 : 1.2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StatCard(
              value: stats.availableOrders.toString(),
              label: 'Có thể nhận',
              icon: Icons.inventory_2_rounded,
              color: AppColors.info,
            ),
            _StatCard(
              value: stats.assignedOrders.toString(),
              label: 'Đơn của bạn',
              icon: Icons.local_shipping_rounded,
              color: AppColors.accent,
            ),
            _StatCard(
              value: stats.activeDeliveries.toString(),
              label: 'Đang giao',
              icon: Icons.route_rounded,
              color: AppColors.warning,
            ),
            _StatCard(
              value: stats.totalDeliveries.toString(),
              label: 'Đã giao',
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
            ),
          ],
        );
      },
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.md,
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.displayMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onRefresh;

  const _QuickActionsRow({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.refresh_rounded,
                label: 'Làm mới',
                onTap: onRefresh,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: _QuickActionButton(
                icon: Icons.navigation_rounded,
                label: 'Điều hướng',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: _QuickActionButton(
                icon: Icons.history_rounded,
                label: 'Lịch sử',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgLight,
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.info, size: 22),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverOrdersSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<OrderModel> orders;
  final String emptyTitle;
  final String emptyMessage;
  final String? acceptDriverId;

  const _DriverOrdersSection({
    required this.title,
    required this.subtitle,
    required this.orders,
    required this.emptyTitle,
    required this.emptyMessage,
    this.acceptDriverId,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (orders.isEmpty)
              _DriverEmptyCard(title: emptyTitle, message: emptyMessage)
            else
              ...orders.map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _DriverOrderCard(
                    order: order,
                    acceptDriverId: acceptDriverId,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DriverOrderCard extends ConsumerStatefulWidget {
  final OrderModel order;
  final String? acceptDriverId;

  const _DriverOrderCard({required this.order, this.acceptDriverId});

  @override
  ConsumerState<_DriverOrderCard> createState() => _DriverOrderCardState();
}

class _DriverOrderCardState extends ConsumerState<_DriverOrderCard> {
  bool _isAccepting = false;

  Future<void> _acceptOrder() async {
    final driverId = widget.acceptDriverId;
    if (_isAccepting || driverId == null || driverId.isEmpty) return;

    setState(() => _isAccepting = true);
    try {
      await ref
          .read(customerOrderServiceProvider)
          .acceptOrder(widget.order.id, driverId);
      ref.invalidate(availableOrdersProvider);
      ref.invalidate(driverOrdersProvider(driverId));
      if (!mounted) return;
      _showSnackBar('Đã nhận đơn hàng.');
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Không thể nhận đơn. Vui lòng thử lại.', isError: true);
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final color = _statusColor(order.status);
    final canAccept = widget.acceptDriverId != null && _isAvailableOrder(order);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: canAccept ? 138 : 110,
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppRadius.full,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_statusIcon(order.status), color: color, size: 21),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _OrderInfoRow(
                  icon: Icons.storefront_rounded,
                  text: order.pickupAddress,
                ),
                const SizedBox(height: AppSpacing.xs),
                _OrderInfoRow(
                  icon: Icons.location_on_outlined,
                  text: order.deliveryAddress,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _MetaPill(
                      icon: Icons.payments_outlined,
                      text: _priceText(order),
                    ),
                    _MetaPill(
                      icon: Icons.local_shipping_rounded,
                      text: _serviceTypeLabel(order.serviceType),
                    ),
                  ],
                ),
                if (canAccept) ...[
                  const SizedBox(height: AppSpacing.md),
                  _AcceptOrderButton(
                    isLoading: _isAccepting,
                    onTap: _isAccepting ? null : _acceptOrder,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AcceptOrderButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onTap;

  const _AcceptOrderButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: onTap == null
            ? AppColors.textMuted.withValues(alpha: 0.24)
            : AppColors.info,
        borderRadius: AppRadius.full,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.full,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textOnAccent,
                    ),
                  )
                else
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.textOnAccent,
                    size: 17,
                  ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  isLoading ? 'Đang nhận...' : 'Nhận đơn',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textOnAccent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _OrderInfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text.isEmpty ? 'Chưa cập nhật' : text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.full,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.xs),
          Text(
            text,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0,
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

class _DriverEmptyCard extends StatelessWidget {
  final String title;
  final String message;

  const _DriverEmptyCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl2),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: AppRadius.lg,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.info,
              size: 24,
            ),
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
        ],
      ),
    );
  }
}

class _MissingDriverProfileState extends StatelessWidget {
  const _MissingDriverProfileState();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl2),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: AppRadius.xl,
              ),
              child: const Icon(
                Icons.badge_outlined,
                color: AppColors.warning,
                size: 30,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Chưa có hồ sơ tài xế',
              textAlign: TextAlign.center,
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tài khoản này đã đăng nhập nhưng chưa được liên kết với bảng tài xế. Vui lòng liên hệ admin để kích hoạt hồ sơ giao hàng.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverLoadingState extends StatelessWidget {
  const _DriverLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _LoadingBlock(height: 168),
        SizedBox(height: AppSpacing.xl2),
        _LoadingBlock(height: 112),
        SizedBox(height: AppSpacing.xl2),
        _LoadingBlock(height: 220),
        SizedBox(height: AppSpacing.xl2),
        _LoadingBlock(height: 240),
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
            color: AppColors.info.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

class _DriverErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _DriverErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _DriverMessageState(
      icon: Icons.error_outline_rounded,
      title: 'Không tải được dữ liệu tài xế',
      message: 'Vui lòng kiểm tra kết nối và thử lại.',
      actionLabel: 'Thử lại',
      onAction: onRetry,
      color: AppColors.error,
    );
  }
}

class _DriverMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color color;

  const _DriverMessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.color = AppColors.info,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl2),
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
      color: AppColors.info,
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

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.card,
      ),
      child: child,
    );
  }
}

class _DriverStats {
  final int availableOrders;
  final int assignedOrders;
  final int activeDeliveries;
  final int totalDeliveries;

  const _DriverStats({
    required this.availableOrders,
    required this.assignedOrders,
    required this.activeDeliveries,
    required this.totalDeliveries,
  });

  factory _DriverStats.fromOrders({
    required DriverModel driver,
    required List<OrderModel> availableOrders,
    required List<OrderModel> driverOrders,
  }) {
    return _DriverStats(
      availableOrders: availableOrders.length,
      assignedOrders: driverOrders.length,
      activeDeliveries: driverOrders.where(_isActiveDriverOrder).length,
      totalDeliveries: driver.totalDeliveries,
    );
  }
}

bool _isActiveDriverOrder(OrderModel order) {
  return order.status == 'assigned' ||
      order.status == 'picking_up' ||
      order.status == 'delivering';
}

bool _isAvailableOrder(OrderModel order) {
  return (order.driverId == null || order.driverId!.isEmpty) &&
      (order.status == 'pending' || order.status == 'confirmed');
}

String _displayOrderCode(OrderModel order) {
  if (order.trackingCode.isNotEmpty) return order.trackingCode;
  final length = order.id.length >= 8 ? 8 : order.id.length;
  return '#${order.id.substring(0, length)}';
}

String _priceText(OrderModel order) {
  final amount = order.totalPrice ?? order.deliveryFee;
  if (amount <= 0) return 'Chưa tính phí';
  return '${amount.toStringAsFixed(0)}đ';
}

String _joinNonEmpty(List<String?> values) {
  return values
      .map((value) => value?.trim() ?? '')
      .where((value) => value.isNotEmpty)
      .join(' · ');
}

String _serviceTypeLabel(String value) {
  return switch (value) {
    'express' => 'Hỏa tốc',
    'fragile' => 'Dễ vỡ',
    'document' => 'Tài liệu',
    _ => 'Tiêu chuẩn',
  };
}

String _statusLabel(String status) {
  return switch (status) {
    'pending' => 'Chờ xác nhận',
    'confirmed' => 'Chờ tài xế',
    'assigned' => 'Đã phân công',
    'picking_up' => 'Đang lấy',
    'delivering' => 'Đang giao',
    'delivered' => 'Hoàn thành',
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
    'confirmed' => Icons.inventory_2_rounded,
    'assigned' => Icons.local_shipping_rounded,
    'picking_up' => Icons.storefront_rounded,
    'delivering' => Icons.local_shipping_outlined,
    'delivered' => Icons.check_circle_rounded,
    'cancelled' => Icons.cancel_rounded,
    _ => Icons.help_outline_rounded,
  };
}
