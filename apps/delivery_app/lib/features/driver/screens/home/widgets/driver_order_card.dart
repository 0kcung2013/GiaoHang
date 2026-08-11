import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../../../../../core/providers/driver_nav_session_provider.dart';
import '../../../../../core/utils/order_cargo_utils.dart';
import '../../../../../core/widgets/order_cargo_info_block.dart';
import '../../../../reviews/widgets/driver_rate_customer_sheet.dart';
import '../../navigation/driver_navigation_screen.dart';
import '../../navigation/widgets/driver_order_cancellation_guard.dart';
import '../../navigation/widgets/driver_risk_action.dart';
import '../utils/driver_home_formatters.dart';
import 'driver_order_card_components.dart';

/// Card đơn hàng dùng chung cho Tổng quan và danh sách đơn của tài xế.
///
/// File này chỉ giữ state/nghiệp vụ. Các thành phần trình bày được tách sang
/// [driver_order_card_components.dart].
class DriverOrderCard extends ConsumerStatefulWidget {
  const DriverOrderCard({
    super.key,
    required this.order,
    this.acceptDriverId,
    this.pickupDistanceMeters,
  });

  final OrderModel order;
  final String? acceptDriverId;
  final double? pickupDistanceMeters;

  @override
  ConsumerState<DriverOrderCard> createState() => _DriverOrderCardState();
}

class _DriverOrderCardState extends ConsumerState<DriverOrderCard> {
  bool _isAccepting = false;
  bool _isTransferring = false;

  Future<void> _acceptOrder() async {
    final driverId = widget.acceptDriverId;
    if (_isAccepting || driverId == null || driverId.isEmpty) return;

    setState(() => _isAccepting = true);
    try {
      await ref
          .read(customerOrderServiceProvider)
          .acceptOrder(
            widget.order.id,
            driverId,
            customerIdHint: widget.order.customerId,
            orderCodeHint: displayOrderCode(widget.order),
          );
      ref.invalidate(availableOrdersProvider(driverId));
      ref.invalidate(driverOrdersProvider(driverId));
      if (!mounted) return;
      _showSnackBar('Đã nhận đơn hàng.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  Future<void> _transferOrder() async {
    final driverId = widget.acceptDriverId;
    if (_isTransferring || driverId == null || driverId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xl),
        title: Text(
          'Chuyển đơn cho tài xế khác?',
          style: AppTextStyles.headingSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Hệ thống sẽ ưu tiên tài xế khác gần điểm lấy hàng. '
          'Bạn sẽ không còn thấy đơn này.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Huỷ',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Chuyển đơn',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isTransferring = true);
    try {
      final nextDriverId = await ref
          .read(customerOrderServiceProvider)
          .transferOrder(widget.order.id, driverId);
      ref.invalidate(availableOrdersProvider(driverId));
      ref.invalidate(driverOrdersProvider(driverId));
      if (!mounted) return;
      _showSnackBar(
        nextDriverId?.isNotEmpty == true
            ? 'Đã chuyển đơn cho tài xế gần hơn.'
            : 'Đã chuyển đơn. Hiện chưa có tài xế khác phù hợp.',
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isTransferring = false);
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
      MaterialPageRoute<void>(
        builder: (_) => DriverOrderCancellationGuard(
          orderId: widget.order.id,
          onCancelled: () {
            return ref
                .read(driverNavSessionsProvider.notifier)
                .remove(widget.order.id);
          },
          child: DriverNavigationScreen(order: widget.order),
        ),
      ),
    );
  }

  Future<void> _openRateCustomer() async {
    final order = widget.order;
    if (order.status != 'delivered') return;

    final existing = await ref.read(
      driverCustomerReviewProvider(order.id).future,
    );
    if (!mounted) return;

    if (existing != null) {
      _showSnackBar('Bạn đã đánh giá khách ${existing.rating}/5 cho đơn này.');
      return;
    }

    await showDriverRateCustomerSheet(context: context, order: order);
    if (mounted) {
      ref.invalidate(driverCustomerReviewProvider(order.id));
    }
  }

  void _onCardTap() {
    if (isActiveDriverOrder(widget.order)) {
      _openNavigation();
    } else if (widget.order.status == 'delivered') {
      _openRateCustomer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final color = statusColor(order.status);
    final canAccept = widget.acceptDriverId != null && isAvailableOrder(order);
    final canContinueDelivery = !canAccept && isActiveDriverOrder(order);
    final isDelivered = order.status == 'delivered';
    final canTap = isActiveDriverOrder(order) || isDelivered;
    final reviewAsync = isDelivered
        ? ref.watch(driverCustomerReviewProvider(order.id))
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canTap ? _onCardTap : null,
        borderRadius: AppRadius.lg,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: AppRadius.lg,
            border: Border.all(
              color: canAccept
                  ? AppColors.accent.withValues(alpha: 0.28)
                  : AppColors.border,
            ),
            boxShadow: AppShadow.subtle,
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: ColoredBox(
                  color: color,
                  child: const SizedBox(width: 4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            statusIcon(order.status),
                            color: color,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            displayOrderCode(order),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        DriverStatusBadge(status: order.status),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DriverOrderInfoRow(
                      icon: Icons.storefront_rounded,
                      iconColor: AppColors.accent,
                      text: order.pickupAddress,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DriverOrderInfoRow(
                      icon: Icons.location_on_rounded,
                      iconColor: AppColors.markerDrop,
                      text: order.deliveryAddress,
                    ),
                    if (hasCargoInfo(order)) ...[
                      const SizedBox(height: AppSpacing.md),
                      OrderCargoInfoBlock(order: order, compact: true),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        if (widget.pickupDistanceMeters != null)
                          DriverMetaPill(
                            icon: Icons.near_me_rounded,
                            text: pickupDistanceText(
                              widget.pickupDistanceMeters,
                            ),
                            emphasized: true,
                          ),
                        DriverMetaPill(
                          icon: Icons.payments_outlined,
                          text: priceText(order),
                        ),
                        DriverMetaPill(
                          icon: Icons.local_shipping_rounded,
                          text: serviceTypeLabel(order.serviceType),
                        ),
                        DriverMetaPill(
                          icon: Icons.access_time_rounded,
                          text: createdTimeText(order),
                        ),
                      ],
                    ),
                    if (canAccept) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: DriverAcceptOrderButton(
                              isLoading: _isAccepting,
                              onTap: _isAccepting ? null : _acceptOrder,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: DriverTransferOrderButton(
                              isLoading: _isTransferring,
                              onTap: _isTransferring ? null : _transferOrder,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (canContinueDelivery) ...[
                      const SizedBox(height: AppSpacing.lg),
                      DriverContinueDeliveryButton(
                        status: order.status,
                        onTap: _openNavigation,
                      ),
                    ],
                    if (!canAccept && (canContinueDelivery || isDelivered)) ...[
                      const SizedBox(height: AppSpacing.md),
                      DriverRiskAction(order: order),
                    ],
                    if (isDelivered) ...[
                      const SizedBox(height: AppSpacing.lg),
                      DriverRateCustomerAction(
                        alreadyRated: reviewAsync?.valueOrNull != null,
                        isLoading: reviewAsync?.isLoading ?? false,
                        onTap: reviewAsync?.isLoading == true
                            ? null
                            : _openRateCustomer,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
