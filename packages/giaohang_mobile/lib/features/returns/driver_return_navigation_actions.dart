part of 'driver_return_navigation_screen.dart';

extension _DriverReturnNavigationActions on _DriverReturnNavigationScreenState {
  Future<void> _loadCancellationState() async {
    final source = widget.repository;
    if (source is! OrderReturnRedeliveryRepository ||
        _mission.status != OrderReturnStatus.returning) {
      return;
    }
    try {
      final allowed = await (source as OrderReturnRedeliveryRepository)
          .canCancelReturn(widget.order.id);
      _updateUi(() => _canCancelReturn = allowed);
    } catch (_) {
      _updateUi(() => _canCancelReturn = false);
    }
  }

  Future<void> _cancelReturn() async {
    final source = widget.repository;
    if (_submitting ||
        !_canCancelReturn ||
        source is! OrderReturnRedeliveryRepository) {
      return;
    }
    if (!await showCancelReturnSheet(context) || !mounted) return;
    _updateUi(() => _submitting = true);
    try {
      final mission = await (source as OrderReturnRedeliveryRepository)
          .cancelReturn(
            orderId: widget.order.id,
            reason: ReturnNavigationStrings.cancelReturnReason,
          );
      if (mission.status != OrderReturnStatus.cancelled) {
        throw StateError('RETURN_CANCEL_NOT_ALLOWED');
      }
      await _tracker.stop();
      if (!mounted) return;
      _updateUi(() {
        _mission = mission;
        _movementStarted = false;
        _canCancelReturn = false;
      });
      await ref
          .read(driverNavSessionsProvider.notifier)
          .remove(widget.order.id);
      if (!mounted) return;
      Navigator.of(context).pop(
        ReturnRedeliveryResult(
          order: widget.order.copyWith(
            status: 'delivering',
            statusNote: ReturnNavigationStrings.cancelReturnReason,
          ),
          position: _position,
        ),
      );
    } catch (_) {
      _updateUi(() => _error = ReturnNavigationStrings.cancelReturnError);
    } finally {
      _updateUi(() => _submitting = false);
    }
  }

  Future<void> _startReturn() async {
    _updateUi(() => _submitting = true);
    try {
      final mission = await widget.repository.startReturn(widget.order.id);
      if (mounted) {
        _updateUi(() {
          _mission = mission;
          _error = null;
        });
        unawaited(_saveNavigationSession());
        await _loadCancellationState();
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
    final result = await showDriverReturnConfirmationSheet(
      context,
      locationProvider: () {
        final position = _position;
        if (position == null) return null;
        return DeliveryProofLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      },
    );
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
        image: result.proof.image,
        capturedAt: result.proof.capturedAt,
        capturedLat: result.proof.location.latitude,
        capturedLng: result.proof.location.longitude,
      );
      final mission = await widget.repository.confirmReturn(
        orderId: widget.order.id,
        receiverName: result.receiverName,
        note: result.note,
      );
      if (!mounted) return;
      _updateUi(() => _mission = mission);
      await _tracker.stop();
      _movementStarted = false;
      await ref
          .read(driverNavSessionsProvider.notifier)
          .remove(widget.order.id);
      if (!mounted) return;
      await showReturnSuccessDialog(
        context,
        returnFee: _mission.driverReturnEarning,
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
      usesRouteSimulation: _usesRouteSimulation,
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
