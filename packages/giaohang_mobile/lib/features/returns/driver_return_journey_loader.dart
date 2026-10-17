part of 'driver_return_navigation_screen.dart';

extension _DriverReturnJourneyLoader on _DriverReturnNavigationScreenState {
  Future<void> _loadJourney() async {
    await _tracker.stop();
    _updateUi(() {
      _loading = true;
      _error = null;
    });
    try {
      await _restoreNavigationSession();
      if (!mounted) return;
      var missionOrigin = LatLng(
        _mission.routeOriginLat,
        _mission.routeOriginLng,
      );
      if (_mission.status == OrderReturnStatus.approved) {
        try {
          final incidentOrigin = await widget.repository.fetchIncidentOrigin(
            _mission.riskReportId,
          );
          missionOrigin = resolveReturnMissionOrigin(
            approvedOrigin: missionOrigin,
            incidentOrigin: incidentOrigin == null
                ? null
                : LatLng(incidentOrigin.$1, incidentOrigin.$2),
          );
        } catch (_) {
          // Báo cáo cũ có thể không đọc được attachment; dùng origin đã duyệt.
        }
      }
      LatLng? currentPoint;
      var currentSource = DriverPositionSource.targetFallback;
      if (_mission.status != OrderReturnStatus.approved) {
        try {
          final loaded = await _loadCurrentPosition();
          currentPoint = loaded.$1;
          currentSource = loaded.$2;
        } catch (_) {
          if (_position == null) rethrow;
          // Khôi phục tiến trình nếu GPS/mạng tạm thời chưa có vị trí mới.
        }
      }
      if (!mounted) return;
      final previousPosition = _position;
      final previousSource = _positionSource;
      final start = resolveReturnJourneyStart(
        usesRouteSimulation: _usesRouteSimulation,
        returnStarted: _mission.status == OrderReturnStatus.returning,
        missionOrigin: missionOrigin,
        currentPosition: currentPoint,
        previousPosition: previousPosition,
        previousSource: previousSource,
      );
      final startSource = _mission.status == OrderReturnStatus.approved
          ? DriverPositionSource.targetFallback
          : shouldKeepReturnJourneyPosition(
              usesRouteSimulation: _usesRouteSimulation,
              previousPosition: previousPosition,
              previousSource: previousSource,
            )
          ? previousSource
          : currentPoint != null
          ? currentSource
          : previousPosition != null
          ? previousSource
          : DriverPositionSource.targetFallback;
      final arrived =
          _mission.status == OrderReturnStatus.returning &&
          ReturnCompletionGuard.distanceMeters(
                currentLat: start.latitude,
                currentLng: start.longitude,
                destinationLat: _destination.latitude,
                destinationLng: _destination.longitude,
              ) <=
              ReturnNavigationTracker.routeEndDistanceMeters;
      final result = arrived
          ? null
          : await OsrmService().getRoute(
              startLat: start.latitude,
              startLng: start.longitude,
              endLat: _destination.latitude,
              endLng: _destination.longitude,
            );
      if (!mounted) return;
      _updateUi(() {
        _position = start;
        _positionSource = startSource;
        _route = result?.points ?? [start, _destination];
        _navigationSteps = result?.steps ?? const [];
        _activeNavigationStepIndex = 0;
        _distance = arrived
            ? 0
            : result?.distanceMeters ??
                  DeliveryMapUtils.remainingMeters([start, _destination]);
        _duration = arrived ? 0 : result?.durationSeconds ?? _distance! / 6.1;
      });
      unawaited(_saveNavigationSession());
      await _loadCancellationState();
      if (!mounted) return;
      if (_usesRouteSimulation &&
          startSource == DriverPositionSource.restoredSession) {
        await _publishPosition(start, force: arrived);
        if (!mounted) return;
      }
      _startMovement();
    } catch (_) {
      if (mounted) {
        _updateUi(
          () => _error = 'Không thể cập nhật vị trí. Hãy bật GPS và thử lại.',
        );
      }
    } finally {
      if (mounted) _updateUi(() => _loading = false);
    }
  }

  Future<(LatLng?, DriverPositionSource)> _loadCurrentPosition() async {
    if (!_usesRouteSimulation) {
      final permission = await Geolocator.checkPermission();
      final allowed =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!allowed) return (null, DriverPositionSource.targetFallback);
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return (
        _resolvePosition(
          LatLng(current.latitude, current.longitude),
          DriverPositionSource.deviceGps,
        ),
        DriverPositionSource.deviceGps,
      );
    }

    try {
      final serverPosition = await _loadServerProfilePosition(refresh: true);
      if (serverPosition != null) {
        return (serverPosition, DriverPositionSource.serverProfile);
      }
    } catch (_) {
      // Trình duyệt vẫn có thể lấy GPS trực tiếp hoặc dùng snapshot đã duyệt.
    }

    final browser = await ref.read(currentPositionProvider.future);
    if (browser == null) return (null, DriverPositionSource.targetFallback);
    return (
      _resolvePosition(
        LatLng(browser.latitude, browser.longitude),
        DriverPositionSource.browserGps,
      ),
      DriverPositionSource.browserGps,
    );
  }

  Future<LatLng?> _loadServerProfilePosition({bool refresh = false}) async {
    final provider = driverByUserIdProvider(_mission.driverId);
    final driver = refresh
        ? await ref.refresh(provider.future)
        : await ref.read(provider.future);
    final lat = driver?.currentLat;
    final lng = driver?.currentLng;
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180 ||
        (lat == 0 && lng == 0)) {
      return null;
    }
    return LatLng(lat, lng);
  }
}
