part of 'driver_return_navigation_screen.dart';

extension _DriverReturnNavigationActions on _DriverReturnNavigationScreenState {
  Future<void> _startReturn() async {
    _updateUi(() => _submitting = true);
    try {
      final mission = await widget.repository.startReturn(widget.order.id);
      if (mounted) {
        _updateUi(() {
          _mission = mission;
          _error = null;
        });
        _startMovement();
      }
    } catch (error) {
      if (mounted) {
        _updateUi(
          () => _error =
              'Không thể bắt đầu hoàn hàng. Vui lòng kiểm tra kết nối.',
        );
      }
    } finally {
      if (mounted) _updateUi(() => _submitting = false);
    }
  }

  Future<void> _completeReturn() async {
    final result = await showDriverReturnConfirmationSheet(context);
    if (result == null || !mounted) return;
    _updateUi(() => _submitting = true);
    try {
      final currentPoint = await _resolveReturnConfirmationPosition();
      if (currentPoint == null) {
        throw StateError('RETURN_LOCATION_REQUIRED');
      }
      final handoffDistance = ReturnCompletionGuard.distanceMeters(
        currentLat: currentPoint.latitude,
        currentLng: currentPoint.longitude,
        destinationLat: _destination.latitude,
        destinationLng: _destination.longitude,
      );
      if (!mounted) return;
      if (!ReturnCompletionGuard.canComplete(handoffDistance)) {
        _updateUi(
          () => _error = ReturnCompletionGuard.blockedMessage(handoffDistance),
        );
        return;
      }
      await (widget.proofService ?? DeliveryProofService()).submitProof(
        orderId: widget.order.id,
        driverId: _mission.driverId,
        stage: DeliveryProofStage.returnHandoff,
        image: result.proofImage,
        capturedLat: currentPoint.latitude,
        capturedLng: currentPoint.longitude,
      );
      final mission = await widget.repository.confirmReturn(
        orderId: widget.order.id,
        receiverName: result.receiverName,
        note: result.note,
      );
      if (!mounted) return;
      _updateUi(() => _mission = mission);
      _tracker.stopSimulation();
      await showReturnSuccessDialog(
        context,
        driverEarning: _mission.driverReturnEarning,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        _updateUi(() => _error = ReturnCompletionGuard.userMessage(error));
      }
    } finally {
      if (mounted) _updateUi(() => _submitting = false);
    }
  }

  Future<LatLng?> _resolveReturnConfirmationPosition() async {
    final strategy = ReturnConfirmationPositionPolicy.resolve(
      isWeb: kIsWeb,
      displayedSource: _positionSource,
    );
    if (strategy == ReturnConfirmationPositionStrategy.displayedPosition) {
      return _position;
    }
    if (strategy == ReturnConfirmationPositionStrategy.serverProfile) {
      final serverPosition = await _loadServerProfilePosition(refresh: true);
      if (serverPosition == null) return null;
      await _onPositionChanged(
        serverPosition,
        source: DriverPositionSource.serverProfile,
      );
      return _position;
    }

    final current = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    await _onPositionChanged(
      LatLng(current.latitude, current.longitude),
      source: kIsWeb
          ? DriverPositionSource.browserGps
          : DriverPositionSource.deviceGps,
    );
    return _position;
  }
}
