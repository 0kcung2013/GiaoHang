import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../../navigation/driver_accepted_order_screen.dart';
import '../driver_home_strings.dart';
import '../utils/driver_home_formatters.dart';
import 'driver_order_card_components.dart';
import 'driver_incoming_offer_presentation.dart';
import 'driver_offer_expiry_builder.dart';
import '../../../cancellation/driver_cancellation_providers.dart';
import '../../../cancellation/driver_cancellation_strings.dart';

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
    this.pickupDistanceMeters,
  });

  final OrderModel order;
  final String driverUserId;
  final double? pickupDistanceMeters;

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
    final acceptance = ref
        .read(driverAcceptanceStateProvider(widget.driverUserId))
        .valueOrNull;
    if (acceptance == null || acceptance.isLocked) {
      _showMessage(DriverCancellationStrings.lockError, isError: true);
      return;
    }
    if (!widget.order.isOfferedToDriverAt(
      widget.driverUserId,
      acceptance.now(),
    )) {
      _refreshOrders();
      _showMessage(DriverHomeStrings.offerExpiredAction, isError: true);
      return;
    }
    // Realtime có thể gỡ widget trước khi HTTP trả về; giữ các owner còn sống.
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final driverUserId = widget.driverUserId;
    final openAccepted = prepareDriverAcceptedOrderNavigation(
      context,
      widget.order.id,
    );
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
      container.invalidate(availableOrdersProvider(driverUserId));
      container.invalidate(driverOrdersProvider(driverUserId));
      openAccepted();
    } catch (error) {
      container.invalidate(availableOrdersProvider(driverUserId));
      container.invalidate(driverOrdersProvider(driverUserId));
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(_errorMessage(error)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
    final acceptance = ref
        .watch(driverAcceptanceStateProvider(widget.driverUserId))
        .valueOrNull;
    final blocked = acceptance == null || acceptance.isLocked;
    return DriverIncomingOfferPresentation(
      order: widget.order,
      pickupDistanceMeters: widget.pickupDistanceMeters,
      now: acceptance?.now,
      actions: DriverOfferExpiryBuilder(
        order: widget.order,
        now: acceptance?.now,
        builder: (context, expired) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DriverAcceptOrderButton(
              isLoading: _isAccepting,
              label: acceptance == null
                  ? DriverHomeStrings.acceptanceChecking
                  : blocked
                  ? DriverCancellationStrings.lockTitle
                  : expired
                  ? DriverHomeStrings.offerExpiredAction
                  : DriverHomeStrings.incomingOfferAccept,
              onTap: _isAccepting || _isTransferring || blocked || expired
                  ? null
                  : _acceptOrder,
            ),
            const SizedBox(height: AppSpacing.sm),
            DriverTransferOrderButton(
              isLoading: _isTransferring,
              onTap: _isAccepting || _isTransferring || expired
                  ? null
                  : _transferOrder,
            ),
          ],
        ),
      ),
    );
  }
}
