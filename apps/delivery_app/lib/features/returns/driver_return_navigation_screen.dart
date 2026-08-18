import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../../core/models/delivery_proof_model.dart';
import '../../core/models/order_model.dart';
import '../../core/providers/customer_providers.dart';
import '../../core/providers/location_providers.dart';
import '../../core/services/delivery_proof_service.dart';
import '../../core/services/osrm_service.dart';
import '../../core/utils/delivery_map_utils.dart';
import '../driver/screens/navigation/models/driver_position_source.dart';
import '../driver/screens/navigation/utils/driver_navigation_route_logic.dart';
import 'data/order_return_repository.dart';
import 'sheets/driver_return_confirmation_sheet.dart';
import 'sheets/return_success_dialog.dart';
import 'utils/return_confirmation_position_policy.dart';
import 'utils/return_completion_guard.dart';
import 'utils/return_journey_start.dart';
import 'utils/return_location_publisher.dart';
import 'utils/return_navigation_tracker.dart';
import 'widgets/return_bottom_panel.dart';
import 'widgets/return_navigation_header.dart';
import 'widgets/return_navigation_map.dart';

part 'driver_return_navigation_actions.dart';
part 'driver_return_journey_loader.dart';

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
  final _mapController = MapController();
  final _tracker = ReturnNavigationTracker();
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

  LatLng get _destination =>
      LatLng(_mission.destinationLat, _mission.destinationLng);

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

  void _updateUi(VoidCallback update) => setState(update);

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
    Future<void>(() {
      if (_navigationOwner.state == orderId) {
        _navigationOwner.state = null;
      }
    });
    unawaited(_tracker.dispose());
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
    if (_mission.status != OrderReturnStatus.returning) return;
    final route = _route;
    if (kIsWeb) {
      if (route == null || route.length < 2) return;
      _tracker.startSimulation(
        route: route,
        currentPosition: _position,
        canMove: () =>
            mounted &&
            _mission.status == OrderReturnStatus.returning &&
            !ReturnCompletionGuard.canComplete(_handoffDistance),
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
      onError: (error) => debugPrint('[RETURN_GPS] $error'),
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
    final arrived =
        source.canConfirmArrival &&
        ReturnCompletionGuard.canComplete(distanceToHandoff);
    if (arrived) {
      published = _destination;
      _tracker.stopSimulation();
    }

    final remaining = route == null
        ? <LatLng>[published, _destination]
        : DeliveryMapUtils.remainingRoute(fullRoute: route, current: published);
    final remainingMeters = arrived
        ? 0.0
        : DeliveryMapUtils.remainingMeters(remaining);
    final nextStepIndex = DriverNavigationRouteLogic.advanceNavigationStepIndex(
      steps: _navigationSteps,
      currentIndex: _activeNavigationStepIndex,
      driverPosition: published,
    );

    setState(() {
      _position = published;
      _positionSource = source;
      _route = arrived ? [published, _destination] : remaining;
      _distance = remainingMeters;
      _duration = remainingMeters / 6.1;
      _activeNavigationStepIndex = nextStepIndex;
      _error = null;
    });
    _followPosition(
      position: published,
      route: arrived ? [published, _destination] : remaining,
    );

    await _publishPosition(published, force: arrived);
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          ReturnNavigationMap(
            controller: _mapController,
            destination: _destination,
            position: _position,
            route: _route,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: ReturnNavigationHeader(
                isApproved: isApproved,
                navigationStep: _nextNavigationStep,
                maneuverDistance: _maneuverDistance,
                remainingDistance: _distance,
                remainingDuration: _duration,
                positionSource: _positionSource,
                onBack: () => Navigator.pop(context),
                onFollowPosition: () => _followPosition(),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ReturnBottomPanel(
              mission: _mission,
              loading: _loading,
              submitting: _submitting,
              distance: _distance,
              duration: _duration,
              handoffDistance: _handoffDistance,
              error: _error,
              onRefresh: _loadJourney,
              onAction: isApproved ? _startReturn : _completeReturn,
            ),
          ),
        ],
      ),
    );
  }
}
