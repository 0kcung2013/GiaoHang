import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../../core/location/driver_active_delivery_tracking_policy.dart';
import '../../core/models/delivery_proof_model.dart';
import '../../core/models/order_model.dart';
import '../../core/providers/customer_providers.dart';
import '../../core/providers/driver_nav_session_provider.dart';
import '../../core/providers/location_providers.dart';
import '../../core/services/delivery_proof_service.dart';
import '../../core/services/delivery_proof_watermark_service.dart';
import '../../core/services/osrm_service.dart';
import '../../core/utils/delivery_map_utils.dart';
import '../driver/screens/navigation/models/driver_position_source.dart';
import '../driver/screens/navigation/utils/driver_navigation_route_logic.dart';
import 'data/order_return_repository.dart';
import 'models/return_map_snapshot.dart';
import 'models/return_redelivery_result.dart';
import 'return_map_screen.dart';
import 'sheets/driver_return_confirmation_sheet.dart';
import 'sheets/cancel_return_sheet.dart';
import 'sheets/return_success_dialog.dart';
import 'utils/return_confirmation_position_policy.dart';
import 'utils/return_completion_guard.dart';
import 'utils/return_journey_start.dart';
import 'utils/return_location_publisher.dart';
import 'utils/return_navigation_tracker.dart';
import 'utils/return_navigation_strings.dart';
import 'widgets/return_bottom_panel.dart';
import 'widgets/return_order_details.dart';

part 'driver_return_navigation_actions.dart';
part 'driver_return_journey_loader.dart';
part 'driver_return_navigation_session.dart';

class DriverReturnNavigationScreen extends ConsumerStatefulWidget {
  const DriverReturnNavigationScreen({
    required this.order,
    required this.mission,
    required this.repository,
    this.proofService,
    super.key,
  });

  final OrderModel order;
  final OrderReturn mission;
  final OrderReturnRepository repository;
  final DeliveryProofService? proofService;

  @override
  ConsumerState<DriverReturnNavigationScreen> createState() =>
      _DriverReturnNavigationScreenState();
}

class _DriverReturnNavigationScreenState
    extends ConsumerState<DriverReturnNavigationScreen> {
  final _tracker = ReturnNavigationTracker();
  final _mapSnapshot = ValueNotifier(const ReturnMapSnapshot());
  late OrderReturn _mission;
  late final StateController<String?> _navigationOwner;
  LatLng? _position;
  DriverPositionSource _positionSource = DriverPositionSource.targetFallback;
  List<LatLng>? _route;
  List<OsrmNavigationStep> _navigationSteps = const [];
  int _activeNavigationStepIndex = 0;
  double? _distance;
  double? _duration;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  bool _showPickup = true;
  bool _movementStarted = false;
  bool _canCancelReturn = false;

  LatLng get _destination =>
      LatLng(_mission.destinationLat, _mission.destinationLng);

  bool get _usesRouteSimulation =>
      DriverActiveDeliveryTrackingPolicy.usesRouteSimulation(
        isWeb: kIsWeb,
        locationMode: ref.read(driverLocationModeProvider),
      );

  OsrmNavigationStep? get _nextNavigationStep =>
      DriverNavigationRouteLogic.nextNavigationStep(
        steps: _navigationSteps,
        activeIndex: _activeNavigationStepIndex,
      );

  double? get _maneuverDistance {
    final position = _position;
    final step = _nextNavigationStep;
    if (position == null || step == null) return null;
    return const Distance().as(LengthUnit.Meter, position, step.location);
  }

  double? get _handoffDistance {
    final position = _position;
    if (position == null) return null;
    return ReturnCompletionGuard.distanceMeters(
      currentLat: position.latitude,
      currentLng: position.longitude,
      destinationLat: _destination.latitude,
      destinationLng: _destination.longitude,
    );
  }

  // Bán kính xác nhận 150 m không phải điểm kết thúc chuyển động GPS.
  bool get _atRouteEnd =>
      (_handoffDistance ?? double.infinity) <=
      ReturnNavigationTracker.routeEndDistanceMeters;

  void _updateUi(VoidCallback update) {
    if (!mounted) return;
    setState(update);
    _mapSnapshot.value = ReturnMapSnapshot(
      position: _position,
      route: _route,
      step: _nextNavigationStep,
      maneuverDistance: _maneuverDistance,
      distance: _distance,
      duration: _duration,
      loading: _loading,
      canStart:
          _mission.status == OrderReturnStatus.returning &&
          !_atRouteEnd &&
          _route != null &&
          _route!.length >= 2,
      running: _movementStarted,
      arrived: _mission.status == OrderReturnStatus.returning && _atRouteEnd,
      error: _error,
    );
  }

  Future<void> _openMap() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ReturnMapScreen(
          snapshot: _mapSnapshot,
          destination: _showPickup
              ? _destination
              : LatLng(widget.order.deliveryLat, widget.order.deliveryLng),
          isReturnRoute: _showPickup,
          onStart: _startGps,
        ),
      ),
    );
  }

  void _startGps() {
    if (_loading ||
        _movementStarted ||
        _mission.status != OrderReturnStatus.returning ||
        _atRouteEnd) {
      return;
    }
    _updateUi(() => _movementStarted = true);
    _startMovement();
  }

  @override
  void initState() {
    super.initState();
    _mission = widget.mission;
    _navigationOwner = ref.read(activeDriverNavigationOrderProvider.notifier);
    Future<void>(() {
      if (!mounted) return;
      _navigationOwner.state = widget.order.id;
      unawaited(_loadJourney());
    });
  }

  @override
  void dispose() {
    final orderId = widget.order.id;
    // Khi hủy hoàn, màn giao đã nhận lại quyền điều hướng cùng mã đơn.
    // Không xóa quyền đó lúc animation đóng màn hoàn kết thúc.
    if (_mission.status != OrderReturnStatus.cancelled) {
      Future<void>(() {
        if (!_navigationOwner.mounted) return;
        if (_navigationOwner.state == orderId) {
          _navigationOwner.state = null;
        }
      });
    }
    unawaited(_tracker.dispose());
    _mapSnapshot.dispose();
    super.dispose();
  }

  LatLng _resolvePosition(LatLng position, DriverPositionSource source) {
    String? email;
    try {
      email = Supabase.instance.client.auth.currentUser?.email;
    } catch (_) {
      // Preview/widget test có thể chưa bootstrap Supabase.
    }
    return source.resolveForPublishing(
      locationMode: ref.read(driverLocationModeProvider),
      email: email,
      position: position,
    );
  }

  void _startMovement() {
    if (!_movementStarted || _mission.status != OrderReturnStatus.returning) {
      return;
    }
    final route = _route;
    if (_usesRouteSimulation) {
      if (route == null || route.length < 2) return;
      _tracker.startSimulation(
        route: route,
        currentPosition: _position,
        canMove: () =>
            mounted &&
            _movementStarted &&
            _mission.status == OrderReturnStatus.returning &&
            !_atRouteEnd,
        onPosition: (position) => _onPositionChanged(
          position,
          source: DriverPositionSource.simulation,
        ),
      );
      return;
    }

    _tracker.startGpsStream(
      onPosition: (position) =>
          _onPositionChanged(position, source: DriverPositionSource.deviceGps),
      onError: (error) {
        debugPrint('[RETURN_GPS] $error');
        _updateUi(() {
          _movementStarted = false;
          _error = ReturnNavigationStrings.gpsError;
        });
        unawaited(_tracker.stop());
      },
    );
  }

  Future<void> _onPositionChanged(
    LatLng rawPosition, {
    required DriverPositionSource source,
  }) async {
    if (!mounted || _mission.status != OrderReturnStatus.returning) return;

    var published = _resolvePosition(rawPosition, source);
    final route = _route;
    if (route != null && route.length >= 2) {
      published = DeliveryMapUtils.snapToRoute(
        fullRoute: route,
        current: published,
      );
    }

    final distanceToHandoff = ReturnCompletionGuard.distanceMeters(
      currentLat: published.latitude,
      currentLng: published.longitude,
      destinationLat: _destination.latitude,
      destinationLng: _destination.longitude,
    );
    final reachedEnd =
        source.canConfirmArrival &&
        distanceToHandoff <= ReturnNavigationTracker.routeEndDistanceMeters;
    if (reachedEnd) {
      _tracker.stopSimulation();
    }

    final remaining = route == null
        ? <LatLng>[published, _destination]
        : DeliveryMapUtils.remainingRoute(fullRoute: route, current: published);
    final remainingMeters = reachedEnd
        ? 0.0
        : DeliveryMapUtils.remainingMeters(remaining);
    final nextStepIndex = DriverNavigationRouteLogic.advanceNavigationStepIndex(
      steps: _navigationSteps,
      currentIndex: _activeNavigationStepIndex,
      driverPosition: published,
    );

    _updateUi(() {
      _position = published;
      _positionSource = source;
      // Giữ geometry gốc để icon còn đường đi giữa hai mẫu, kể cả qua góc cua.
      _distance = remainingMeters;
      _duration = remainingMeters / 6.1;
      _activeNavigationStepIndex = nextStepIndex;
      _error = null;
      if (reachedEnd) _movementStarted = false;
    });

    unawaited(_saveNavigationSession());
    await _publishPosition(published, force: reachedEnd);
  }

  Future<void> _publishPosition(LatLng position, {bool force = false}) async {
    try {
      await ReturnLocationPublisher(
        realtimeService: ref.read(realtimeServiceProvider),
        locationIngestService: ref.read(locationIngestServiceProvider),
      ).publish(
        orderId: widget.order.id,
        driverId: _mission.driverId,
        position: position,
        force: force,
      );
    } catch (error) {
      debugPrint('[RETURN_LOCATION_SYNC] $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isApproved = _mission.status == OrderReturnStatus.approved;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.bgLight,
        foregroundColor: AppColors.primary,
        surfaceTintColor: AppColors.bgLight,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          tooltip: ReturnNavigationStrings.back,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(widget.order.trackingCode, style: AppTextStyles.mono),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ReturnOrderDetails(
            order: widget.order,
            mission: _mission,
            showPickup: _showPickup,
            onSelectPickup: (pickup) => setState(() => _showPickup = pickup),
            onOpenMap: _openMap,
          ),
        ),
      ),
      bottomNavigationBar: ReturnBottomPanel(
        mission: _mission,
        loading: _loading,
        submitting: _submitting,
        distance: _distance,
        duration: _duration,
        handoffDistance: _handoffDistance,
        error: _error,
        onRefresh: _loadJourney,
        onAction: isApproved ? _startReturn : _completeReturn,
        onCancelReturn: _canCancelReturn ? _cancelReturn : null,
      ),
    );
  }
}
