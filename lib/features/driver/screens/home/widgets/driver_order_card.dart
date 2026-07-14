import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../../../../../core/utils/order_cargo_utils.dart';
import '../../../../../core/widgets/order_cargo_info_block.dart';
import '../../navigation/driver_navigation_screen.dart';
import '../utils/driver_home_formatters.dart';
import 'slide_status_action.dart';

/// A single order row card used in both "available" and "assigned" sections.
class DriverOrderCard extends ConsumerStatefulWidget {
  final OrderModel order;
  final String? acceptDriverId;

  const DriverOrderCard({super.key, required this.order, this.acceptDriverId});

  @override
  ConsumerState<DriverOrderCard> createState() => _DriverOrderCardState();
}

class _DriverOrderCardState extends ConsumerState<DriverOrderCard> {
  bool _isAccepting = false;
  bool _isRejecting = false;
  bool _isUpdatingStatus = false;

  Future<void> _acceptOrder() async {
    final driverId = widget.acceptDriverId;
    if (_isAccepting || driverId == null || driverId.isEmpty) return;

    setState(() => _isAccepting = true);
    try {
      await ref
          .read(customerOrderServiceProvider)
          .acceptOrder(widget.order.id, driverId);
      ref.invalidate(availableOrdersProvider(driverId));
      ref.invalidate(driverOrdersProvider(driverId));
      if (!mounted) return;
      _showSnackBar('Đã nhận đơn hàng.');
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      _showSnackBar(msg, isError: true);
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  Future<void> _rejectOrder() async {
    final driverId = widget.acceptDriverId;
    if (_isRejecting || driverId == null || driverId.isEmpty) return;

    setState(() => _isRejecting = true);
    try {
      await ref
          .read(customerOrderServiceProvider)
          .rejectOrder(widget.order.id, driverId);
      ref.invalidate(availableOrdersProvider(driverId));
      ref.invalidate(driverOrdersProvider(driverId));
      if (!mounted) return;
      _showSnackBar('Đã từ chối đơn hàng.');
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      _showSnackBar(msg, isError: true);
    } finally {
      if (mounted) setState(() => _isRejecting = false);
    }
  }

  Future<void> _updateOrderStatus() async {
    final driverId = widget.order.driverId;
    if (_isUpdatingStatus || driverId == null || driverId.isEmpty) return;

    setState(() => _isUpdatingStatus = true);
    try {
      final nextStatus = await ref
          .read(customerOrderServiceProvider)
          .updateDriverOrderStatus(
            orderId: widget.order.id,
            driverId: driverId,
            currentStatus: widget.order.status,
          );
      ref.invalidate(availableOrdersProvider(driverId));
      ref.invalidate(driverOrdersProvider(driverId));
      ref.invalidate(orderByIdProvider(widget.order.id));
      if (!mounted) return;
      final message = nextStatus == 'delivered'
          ? 'Đã hoàn tất giao hàng.'
          : 'Đã cập nhật trạng thái đơn hàng.';
      _showSnackBar(message);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      _showSnackBar(msg, isError: true);
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
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

  void _openNavigation() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverNavigationScreen(order: widget.order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final color = statusColor(order.status);
    final canAccept = widget.acceptDriverId != null && isAvailableOrder(order);
    final statusActionLabel = driverOrderStatusActionLabel(order.status);
    final canUpdateStatus =
        !canAccept && statusActionLabel != null && order.driverId != null;
    final hasAction = canAccept || canUpdateStatus;
    final isActive = isActiveDriverOrder(order);

    return GestureDetector(
      onTap: isActive ? _openNavigation : null,
      child: Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status accent bar
          Container(
            width: 3,
            height: hasAction ? 138 : 110,
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppRadius.full,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Status icon circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon(order.status), color: color, size: 21),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order code + badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayOrderCode(order),
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
                if (hasCargoInfo(order)) ...[
                  const SizedBox(height: AppSpacing.sm),
                  OrderCargoInfoBlock(order: order, compact: true),
                ],
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _MetaPill(
                      icon: Icons.payments_outlined,
                      text: priceText(order),
                    ),
                    _MetaPill(
                      icon: Icons.local_shipping_rounded,
                      text: serviceTypeLabel(order.serviceType),
                    ),
                    _MetaPill(
                      icon: Icons.access_time_rounded,
                      text: createdTimeText(order),
                    ),
                  ],
                ),
                if (canAccept) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _AcceptOrderButton(
                          isLoading: _isAccepting,
                          onTap: _isAccepting ? null : _acceptOrder,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _RejectOrderButton(
                          isLoading: _isRejecting,
                          onTap: _isRejecting ? null : _rejectOrder,
                        ),
                      ),
                    ],
                  ),
                ],
                if (canUpdateStatus) ...[
                  const SizedBox(height: AppSpacing.md),
                  SlideStatusAction(
                    label: statusActionLabel,
                    isLoading: _isUpdatingStatus,
                    onConfirmed: _isUpdatingStatus ? null : _updateOrderStatus,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ─── Sub-widgets ───────────────────────────────────────────────────────────

class _AcceptOrderButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onTap;

  const _AcceptOrderButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
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
            mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }
}

class _RejectOrderButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onTap;

  const _RejectOrderButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null
          ? AppColors.textMuted.withValues(alpha: 0.24)
          : AppColors.error.withValues(alpha: 0.08),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.error,
                  ),
                )
              else
                const Icon(
                  Icons.cancel_rounded,
                  color: AppColors.error,
                  size: 17,
                ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                isLoading ? 'Đang từ chối...' : 'Từ chối',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.error,
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
    final color = statusColor(status);

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
        statusLabel(status),
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
