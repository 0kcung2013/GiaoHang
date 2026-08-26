import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../driver_home_strings.dart';
import '../utils/driver_home_formatters.dart';
import 'driver_offer_countdown.dart';
import 'driver_order_card_components.dart';
import 'driver_order_finance_panel.dart';

OrderModel? selectIncomingOfferForTab({
  required int tabIndex,
  required List<OrderModel> offers,
}) {
  if (tabIndex == 0 || offers.isEmpty) return null;
  return offers.first;
}

class DriverIncomingOfferOverlay extends ConsumerStatefulWidget {
  const DriverIncomingOfferOverlay({
    super.key,
    required this.order,
    required this.driverUserId,
  });

  final OrderModel order;
  final String driverUserId;

  @override
  ConsumerState<DriverIncomingOfferOverlay> createState() =>
      _DriverIncomingOfferOverlayState();
}

class _DriverIncomingOfferOverlayState
    extends ConsumerState<DriverIncomingOfferOverlay> {
  bool _isAccepting = false;
  bool _isTransferring = false;

  Future<void> _acceptOrder() async {
    if (_isAccepting || _isTransferring) return;
    setState(() => _isAccepting = true);
    try {
      await ref
          .read(customerOrderServiceProvider)
          .acceptOrder(
            widget.order.id,
            widget.driverUserId,
            customerIdHint: widget.order.customerId,
            orderCodeHint: displayOrderCode(widget.order),
          );
      _refreshOrders();
      if (mounted) {
        _showMessage(DriverHomeStrings.incomingOfferAcceptSuccess);
      }
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error), isError: true);
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  Future<void> _transferOrder() async {
    if (_isAccepting || _isTransferring) return;
    setState(() => _isTransferring = true);
    try {
      await ref
          .read(customerOrderServiceProvider)
          .transferOrder(widget.order.id, widget.driverUserId);
      _refreshOrders();
      if (mounted) {
        _showMessage(DriverHomeStrings.incomingOfferTransferSuccess);
      }
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error), isError: true);
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  void _refreshOrders() {
    ref.invalidate(availableOrdersProvider(widget.driverUserId));
    ref.invalidate(driverOrdersProvider(widget.driverUserId));
  }

  String _errorMessage(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty
        ? DriverHomeStrings.incomingOfferActionError
        : message;
  }

  void _showMessage(String message, {bool isError = false}) {
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
    final orderCode = displayOrderCode(order);

    return Material(
      key: const ValueKey('driver-incoming-offer-overlay'),
      color: AppColors.bgDark,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.bgDark, AppColors.primary],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - AppSpacing.screenH * 2,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _OfferHero(orderCode: orderCode),
                      const SizedBox(height: AppSpacing.xl2),
                      _OfferCard(
                        order: order,
                        isAccepting: _isAccepting,
                        isTransferring: _isTransferring,
                        onAccept: _acceptOrder,
                        onTransfer: _transferOrder,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OfferHero extends StatelessWidget {
  const _OfferHero({required this.orderCode});

  final String orderCode;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: DriverHomeStrings.incomingOfferSemantic(orderCode),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              boxShadow: AppShadow.accentGlow,
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: AppColors.textOnAccent,
              size: 34,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.16),
              borderRadius: AppRadius.full,
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              DriverHomeStrings.incomingOfferBadge,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            DriverHomeStrings.incomingOfferTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.displayMedium.copyWith(
              color: AppColors.textOnDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            DriverHomeStrings.incomingOfferSubtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textOnDark.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.order,
    required this.isAccepting,
    required this.isTransferring,
    required this.onAccept,
    required this.onTransfer,
  });

  final OrderModel order;
  final bool isAccepting;
  final bool isTransferring;
  final VoidCallback onAccept;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl2,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayOrderCode(order),
            style: AppTextStyles.mono.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          DriverOrderInfoRow(
            icon: Icons.storefront_rounded,
            iconColor: AppColors.markerPickup,
            text: order.pickupAddress,
          ),
          const SizedBox(height: AppSpacing.md),
          DriverOrderInfoRow(
            icon: Icons.location_on_rounded,
            iconColor: AppColors.markerDrop,
            text: order.deliveryAddress,
          ),
          const SizedBox(height: AppSpacing.lg),
          DriverOrderFinancePanel(order: order),
          if (order.offerExpiresAt != null) ...[
            const SizedBox(height: AppSpacing.lg),
            DriverOfferCountdown(expiresAt: order.offerExpiresAt!),
          ],
          const SizedBox(height: AppSpacing.xl),
          DriverAcceptOrderButton(
            isLoading: isAccepting,
            label: DriverHomeStrings.incomingOfferAccept,
            icon: Icons.check_circle_rounded,
            onTap: isAccepting || isTransferring ? null : onAccept,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: DriverTransferOrderButton(
              isLoading: isTransferring,
              onTap: isAccepting || isTransferring ? null : onTransfer,
            ),
          ),
        ],
      ),
    );
  }
}
