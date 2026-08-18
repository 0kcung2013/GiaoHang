part of 'driver_return_navigation_screen.dart';

extension _DriverReturnJourneyLoader on _DriverReturnNavigationScreenState {
  Future<void> _loadJourney() async {
    _tracker.stopSimulation();
    _updateUi(() {
      _loading = true;
      _error = null;
    });
    try {
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
        final loaded = await _loadCurrentPosition();
        currentPoint = loaded.$1;
        currentSource = loaded.$2;
      }
      final previousPosition = _position;
      final previousSource = _positionSource;
      final start = resolveReturnJourneyStart(
        isWeb: kIsWeb,
        returnStarted: _mission.status == OrderReturnStatus.returning,
        missionOrigin: missionOrigin,
        currentPosition: currentPoint,
        previousPosition: previousPosition,
        previousSource: previousSource,
      );
      final startSource = _mission.status == OrderReturnStatus.approved
          ? DriverPositionSource.targetFallback
          : previousSource == DriverPositionSource.simulation &&
                previousPosition != null
          ? previousSource
          : currentPoint != null
          ? currentSource
          : previousPosition != null
          ? previousSource
          : DriverPositionSource.targetFallback;
      final result = await OsrmService().getRoute(
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
        _distance =
            result?.distanceMeters ?? _mission.routeDistanceMeters.toDouble();
        _duration =
            result?.durationSeconds ?? _mission.routeDurationSeconds.toDouble();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_mission.status == OrderReturnStatus.returning &&
            _position != null) {
          _followPosition();
        } else {
          _fitRoute();
        }
      });
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
    if (!kIsWeb) {
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
      final serverPosition = await _loadServerProfilePosition();
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
    if (lat == null || lng == null || lat == 0 || lng == 0) return null;
    return LatLng(lat, lng);
  }

  void _fitRoute() {
    final points = _route;
    if (!mounted || points == null || points.length < 2) return;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(48, 230, 48, 220),
      ),
    );
  }

  void _followPosition({LatLng? position, List<LatLng>? route}) {
    final currentPosition = position ?? _position;
    if (currentPosition == null) {
      _fitRoute();
      return;
    }
    DriverNavigationRouteLogic.followRouteCamera(
      controller: _mapController,
      driverPosition: currentPosition,
      routePoints: route ?? _route,
      fallbackTarget: _destination,
    );
  }
}
