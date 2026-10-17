import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../../navigation/driver_accepted_order_screen.dart';
import '../driver_home_strings.dart';
import '../providers/driver_offer_acceptance_provider.dart';
import '../utils/driver_home_formatters.dart';
import 'driver_incoming_offer_actions.dart';
import 'driver_incoming_offer_presentation.dart';
import 'driver_offer_expiry_builder.dart';
import '../../../cancellation/driver_cancellation_providers.dart';
import '../../../cancellation/driver_cancellation_strings.dart';
import '../../../offer_transfer/dialogs/confirm_order_transfer_sheet.dart';
import '../../../offer_transfer/driver_offer_transfer_strings.dart';
import '../../../offer_transfer/models/driver_offer_transfer_state.dart';
import '../../../offer_transfer/utils/refresh_transfer_acceptance.dart';

OrderModel? selectIncomingOfferForTab({
  required int tabIndex,
  required List<OrderModel> offers,
}) {
  if (offers.isEmpty) return null;
  return offers.first;
}

class DriverIncomingOfferOverlay extends ConsumerStatefulWidget {
  const DriverIncomingOfferOverlay({
    super.key,
    required this.order,
    required this.driverUserId,
    this.driverPosition,
    this.onResolved,
  });

  final OrderModel order;
  final String driverUserId;
  final LatLng? driverPosition;
  final VoidCallback? onResolved;

  @override
  ConsumerState<DriverIncomingOfferOverlay> createState() =>
      _DriverIncomingOfferOverlayState();
}

class _DriverIncomingOfferOverlayState
    extends ConsumerState<DriverIncomingOfferOverlay> {
  bool _isAccepting = false;
  bool _isTransferring = false;
  bool _isConfirmingTransfer = false;
  bool get _offerActionBusy =>
      _isAccepting || _isTransferring || _isConfirmingTransfer;

  Future<void> _acceptOrder() async {
    if (_offerActionBusy) return;
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
    final onResolved = widget.onResolved;
    final openAccepted = prepareDriverAcceptedOrderNavigation(
      context,
      widget.order.id,
      rootNavigator: true,
    );
    setState(() => _isAccepting = true);
    try {
      await ref.read(driverOfferAcceptanceProvider)(
        widget.order,
        widget.driverUserId,
        orderCodeHint: displayOrderCode(widget.order),
      );
      container.invalidate(availableOrdersProvider(driverUserId));
      container.invalidate(driverOrdersProvider(driverUserId));
      onResolved?.call();
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
    if (_offerActionBusy) return;
    final acceptance = ref
        .read(driverAcceptanceStateProvider(widget.driverUserId))
        .valueOrNull;
    if (acceptance == null || acceptance.isLocked) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final driverUserId = widget.driverUserId;
    final onResolved = widget.onResolved;
    setState(() => _isConfirmingTransfer = true);
    try {
      final confirmed = await showConfirmOrderTransferSheet(
        context,
        transfers: acceptance.transfers,
      );
      if (!confirmed || !mounted) return;
      if (!widget.order.isOfferedToDriverAt(driverUserId, acceptance.now())) {
        _refreshOrders();
        _showMessage(DriverHomeStrings.offerExpiredAction, isError: true);
        return;
      }
      setState(() {
        _isConfirmingTransfer = false;
        _isTransferring = true;
      });
      await ref
          .read(customerOrderServiceProvider)
          .transferOrder(widget.order.id, driverUserId);
      onResolved?.call();
      container.invalidate(availableOrdersProvider(driverUserId));
      container.invalidate(driverOrdersProvider(driverUserId));
      // Realtime có thể gỡ lời mời trước khi RPC trả về. Vẫn đồng bộ hạn mức.
      final state = await refreshTransferAcceptance(container, driverUserId);
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              state?.isLocked == true &&
                      state?.lockReason == DriverOfferTransferState.lockReason
                  ? DriverOfferTransferStrings.lockedMessage
                  : DriverHomeStrings.incomingOfferTransferSuccess,
            ),
            backgroundColor: state?.isLocked == true
                ? AppColors.warning
                : AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      container.invalidate(driverAcceptanceStateProvider(driverUserId));
      if (mounted) _showMessage(_errorMessage(error), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isConfirmingTransfer = false;
          _isTransferring = false;
        });
      }
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
      driverId: widget.driverUserId,
      driverPosition: widget.driverPosition,
      actions: DriverOfferExpiryBuilder(
        order: widget.order,
        now: acceptance?.now,
        builder: (context, expired) => DriverIncomingOfferActions(
          expiresAt:
              widget.order.offerExpiresAt == null ||
                  widget.order.offerExpiresAt!.isAfter(
                    widget.order.assignmentDeadline,
                  )
              ? widget.order.assignmentDeadline
              : widget.order.offerExpiresAt!,
          now: acceptance?.now,
          expired: expired,
          isAccepting: _isAccepting,
          isTransferring: _isTransferring,
          label: acceptance == null
              ? DriverHomeStrings.acceptanceChecking
              : blocked
              ? DriverCancellationStrings.lockTitle
              : expired
              ? DriverHomeStrings.offerExpiredAction
              : DriverHomeStrings.incomingOfferAccept,
          onAccept: _offerActionBusy || blocked || expired
              ? null
              : _acceptOrder,
          onSkip: _offerActionBusy || expired || blocked
              ? null
              : _transferOrder,
          transfers: blocked ? null : acceptance.transfers,
        ),
      ),
    );
  }
}
