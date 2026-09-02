part of 'driver_navigation_screen.dart';

extension _DriverNavigationDeliveryActions on _DriverNavigationScreenState {
  Future<void> _handlePrimaryAction() async {
    if (_isUpdatingStatus) return;
    final workflow = DriverDeliveryWorkflow.fromStatus(
      _currentOrder.status,
      pickupConfirmed: _pickupConfirmed,
    );

    if (workflow.action == DriverDeliveryAction.startDelivery) {
      await _startDelivery();
      return;
    }
    if (workflow.action == DriverDeliveryAction.none) return;
    if (!workflow.canPerform(arrivedAtTarget: _arrivedAtTarget)) {
      _showArrivalRequiredMessage();
      return;
    }

    final confirmation = await showDriverDeliveryConfirmationSheet(
      context: context,
      action: workflow.action,
      order: _currentOrder,
      locationProvider: () {
        final position = _driverPos;
        if (position == null) return null;
        return DeliveryProofLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      },
    );
    if (confirmation != null && mounted) {
      await _applyConfirmedAction(
        action: workflow.action,
        confirmation: confirmation,
      );
    }
  }

  void _showArrivalRequiredMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bạn cần đến trong phạm vi 100 m để xác nhận.'),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _applyConfirmedAction({
    required DriverDeliveryAction action,
    required DriverDeliveryConfirmationResult confirmation,
  }) async {
    _updateUi(() => _isUpdatingStatus = true);
    try {
      await _submitHandoffProof(action: action, confirmation: confirmation);

      if (!action.advancesOrderStatusImmediately) {
        _simTimer?.cancel();
        _simTimer = null;
        if (!mounted) return;
        _updateUi(() {
          _pickupConfirmed = true;
          _arrivedAtTarget = true;
          _totalDistance = 0;
          _totalDuration = 0;
        });
        _persistNavSession();
        _showWorkflowMessage(
          'Đã xác nhận lấy hàng. GPS đang chờ bạn bắt đầu giao.',
        );
        return;
      }

      await _advanceOrderStatus();
    } catch (error) {
      _showStatusError(error);
    } finally {
      if (mounted) _updateUi(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _startDelivery() async {
    if (_currentOrder.status != 'picking_up' || !_pickupConfirmed) {
      _showWorkflowMessage('Hãy xác nhận đã lấy hàng trước khi bắt đầu giao.');
      return;
    }

    _updateUi(() => _isUpdatingStatus = true);
    try {
      await _advanceOrderStatus();
    } catch (error) {
      _showStatusError(error);
    } finally {
      if (mounted) _updateUi(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _submitHandoffProof({
    required DriverDeliveryAction action,
    required DriverDeliveryConfirmationResult confirmation,
  }) async {
    final proofStage = switch (action) {
      DriverDeliveryAction.confirmPickup => DeliveryProofStage.pickup,
      DriverDeliveryAction.confirmDelivery => DeliveryProofStage.delivery,
      _ => null,
    };
    if (proofStage == null) return;

    final proof = confirmation.proof;
    if (proof == null) {
      throw Exception('Bạn cần chụp ảnh xác nhận trước khi tiếp tục.');
    }
    await ref
        .read(deliveryProofServiceProvider)
        .submitProof(
          orderId: _currentOrder.id,
          driverId: _currentOrder.driverId ?? '',
          stage: proofStage,
          image: proof.image,
          capturedAt: proof.capturedAt,
          capturedLat: proof.location.latitude,
          capturedLng: proof.location.longitude,
        );
  }

  Future<void> _advanceOrderStatus() async {
    final isStartingDelivery = _currentOrder.status == 'picking_up';
    var walletBefore = ref
        .read(driverWalletSummaryProvider)
        .valueOrNull
        ?.availableBalance;
    if (isStartingDelivery && walletBefore == null) {
      try {
        walletBefore =
            (await ref.read(driverWalletServiceProvider).getSummary())
                .availableBalance;
      } catch (_) {
        // The status RPC remains authoritative and re-checks the balance.
      }
    }
    final nextStatus = await ref
        .read(customerOrderServiceProvider)
        .updateDriverOrderStatus(
          orderId: _currentOrder.id,
          driverId: _currentOrder.driverId ?? '',
          currentStatus: _currentOrder.status,
        );

    final driverId = _currentOrder.driverId ?? '';
    ref.invalidate(availableOrdersProvider(driverId));
    ref.invalidate(driverOrdersProvider(driverId));
    ref.invalidate(driverWalletSummaryProvider);
    ref.invalidate(driverWalletTransactionsProvider);
    if (!mounted) return;

    if (isStartingDelivery &&
        nextStatus == 'delivering' &&
        _currentOrder.driverAdvanceAmount > 0) {
      int? availableBalance = walletBefore == null
          ? null
          : walletBefore - _currentOrder.driverAdvanceAmount;
      try {
        final wallet = await ref.read(driverWalletServiceProvider).getSummary();
        availableBalance = wallet.availableBalance;
      } catch (_) {
        if (availableBalance != null && availableBalance < 0) {
          availableBalance = 0;
        }
      }
      if (!mounted) return;
      await showDriverWalletDebitDialog(
        context: context,
        debitedAmount: _currentOrder.driverAdvanceAmount,
        availableBalance: availableBalance,
      );
      if (!mounted) return;
    }

    if (nextStatus == 'delivered') {
      final deliveredOrder = _currentOrder.copyWith(status: nextStatus);
      _simTimer?.cancel();
      _simTimer = null;
      _routeRefreshTimer?.cancel();
      _routeRefreshTimer = null;
      _updateUi(() {
        _currentOrder = deliveredOrder;
        _totalDistance = 0;
        _totalDuration = 0;
        _arrivedAtTarget = true;
        _pickupConfirmed = false;
      });
      await _navSessionsNotifier.remove(deliveredOrder.id);
      await DriverForegroundLocationService.stop();
      if (!mounted) return;
      await showDriverDeliverySuccessDialog(context);
      if (!mounted) return;
      await showDriverRateCustomerSheet(
        context: context,
        order: deliveredOrder,
        customerName: null,
      );
      return;
    }

    final keepPickupArrival = nextStatus == 'picking_up' && _arrivedAtTarget;
    _simTimer?.cancel();
    _simTimer = null;
    _updateUi(() {
      _currentOrder = _currentOrder.copyWith(status: nextStatus);
      _lastRouteStatus = null;
      _routePoints = null;
      _navigationSteps = const [];
      _activeNavigationStepIndex = 0;
      _totalDistance = null;
      _totalDuration = null;
      _arrivedAtTarget = keepPickupArrival;
      _pickupConfirmed = false;
      _simRouteIndex = 0;
    });
    _persistNavSession();
    await _loadRoute();
    _fitMapBounds();
  }

  void _showStatusError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi cập nhật trạng thái: $error'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showWorkflowMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
