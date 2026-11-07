import 'dart:async';
import '../../../../core/location/driver_arrival_fix.dart';
import '../../../../core/location/driver_workload_policy.dart';
import '../../recipient_hold/recipient_hold_sheet.dart';
import '../../recipient_hold/recipient_hold_repository.dart';
import '../../recipient_hold/recipient_hold_strings.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/location/driver_active_delivery_tracking_policy.dart';
import '../../../../core/location/driver_location_producer_policy.dart';
import '../../../../core/models/delivery_proof_model.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/models/delivery_eta_route_profile.dart';
import '../../../../core/providers/customer_providers.dart';
import '../../../../core/providers/driver_nav_session_provider.dart';
import '../../../../core/providers/driver_task_priority_provider.dart';
import '../../../../core/providers/driver_wallet_providers.dart';
import '../../../../core/providers/location_providers.dart';
import '../../../../core/providers/driver_position_publisher_provider.dart';
import 'data/driver_navigation_routing_provider.dart';
import 'utils/driver_navigation_location_strings.dart';
import '../../../../core/services/osrm_service.dart';
import '../../../../core/services/driver_order_acceptance_gateway.dart';
import '../../../../core/services/delivery_proof_watermark_service.dart';
import '../../../../core/utils/delivery_map_utils.dart';
import '../../../delivery_eta/utils/driver_departure_detector.dart';
import '../../../delivery_eta/order_eta_providers.dart';
import '../../../reviews/widgets/driver_rate_customer_sheet.dart';
import '../../../order_handoff/data/pickup_handoff_service.dart';
import '../../../order_handoff/pickup_handoff_strings.dart';
import '../../../order_contact/models/order_contact_message.dart';
import '../../../order_contact/order_contact_strings.dart';
import '../../../order_contact/widgets/arrival_contact_sheet.dart';
import '../../../order_contact/widgets/demo_call_sheet.dart';
import '../../../order_contact/widgets/order_contact_chat_sheet.dart';
import '../../../risk_reports/data/risk_intervention_repository.dart';
import '../../../risk_reports/data/participant_risk_report_query_repository.dart';
import '../../../risk_reports/widgets/risk_report_sheet.dart';
import '../../../risk_reports/utils/risk_report_strings.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'models/driver_arrival_policy.dart';
import 'data/driver_delivery_arrival_repository.dart';
import 'models/driver_delivery_workflow.dart';
import 'models/driver_late_delivery_notice.dart';
import 'widgets/driver_late_delivery_notice_dialog.dart';
import 'utils/driver_navigation_motion.dart';
import 'utils/driver_navigation_route_logic.dart';
import 'widgets/driver_delivery_confirmation_sheet.dart';
import 'widgets/driver_delivery_success_dialog.dart';
import 'widgets/driver_navigation_map.dart';
import 'widgets/driver_navigation_view.dart';
import 'widgets/driver_wallet_debit_dialog.dart';
import '../../cancellation/driver_cancellation_providers.dart';
import '../../cancellation/driver_cancellation_strings.dart';
import '../../cancellation/dialogs/driver_support_cancellation_dialog.dart';
import '../../finance/models/driver_goods_deposit.dart';
import '../../finance/providers/driver_goods_deposit_provider.dart';
import '../../finance/widgets/driver_goods_deposit_panel.dart';
import '../../../returns/models/return_redelivery_result.dart';
import '../../monitoring/driver_monitoring_providers.dart';
import '../../monitoring/driver_monitoring_release_actions.dart';
import '../../monitoring/widgets/driver_monitoring_guard.dart';
import '../../monitoring/widgets/driver_monitoring_panel.dart';

part 'driver_navigation_delivery_actions.dart';
part 'driver_navigation_location_actions.dart';
part 'driver_navigation_route_actions.dart';
part 'driver_navigation_contact_actions.dart';
part 'driver_navigation_arrival_actions.dart';
part 'driver_navigation_hold_actions.dart';
part 'driver_navigation_deadline_actions.dart';
part 'driver_navigation_support_actions.dart';
part 'driver_navigation_finance_actions.dart';
part 'driver_navigation_eta_actions.dart';
part 'driver_navigation_monitoring_actions.dart';

class DriverNavigationScreen extends ConsumerStatefulWidget {
  final OrderModel order;
  final RiskInterventionRepository? riskInterventionRepository;

  const DriverNavigationScreen({
    super.key,
    required this.order,
    this.riskInterventionRepository,
  });

  @override
  ConsumerState<DriverNavigationScreen> createState() =>
      _DriverNavigationScreenState();
}

class _DriverNavigationScreenState
    extends ConsumerState<DriverNavigationScreen> {
  late OrderModel _currentOrder;
  final MapController _mapController = MapController();
  List<LatLng>? _routePoints;
  List<OsrmNavigationStep> _navigationSteps = const [];
  int _activeNavigationStepIndex = 0;
  double? _totalDistance;
  double? _totalDuration;
  bool _isUpdatingStatus = false;
  bool _isRouting = false;
  bool _routeFailed = false;

  LatLng? _driverPos;
  int _simRouteIndex = 0;

  Timer? _routeRefreshTimer;
  Timer? _simTimer; // Chỉ dùng khi web simulate
  Timer? _monitoringHeartbeatTimer;
  bool _monitoringHeartbeatPending = false;

  String? _lastRouteStatus;
  int _routeKey = 0;
  DateTime _lastCameraFollowAt = DateTime.fromMillisecondsSinceEpoch(0);
  LatLng? _lastCameraFollowPosition;

  bool _arrivedAtTarget = false;
  bool _routeCompleted = false;
  bool _pickupConfirmed = false;
  bool _exitingForOrderCancellation = false;
  bool _simulationRequested = false;
  final _etaDepartureDetector = DriverDepartureDetector();
  bool _etaDeparturePending = false;
  bool _etaDepartureRecorded = false;
  DateTime? _etaDepartureRetryAt;

  static const Duration _simulationTick = Duration(milliseconds: 250);
  final _speedProfileCache = DeliveryEtaRouteProfileCache();
  DeliveryEtaRouteProfile? get _speedProfile =>
      _speedProfileCache.resolve(_currentOrder);
  double get _movementSpeedKmh => _canSimulateMovement && _driverPos != null
      ? _speedProfile?.speedAt(_driverPos!) ?? 25
      : 0;

  late final StateController<String?> _navigationOwner;
  late final StateController<DriverLocationMode> _navigationLocationMode;
  late final DriverNavSessionsNotifier _navSessionsNotifier;
  late final RiskInterventionRepository? _riskInterventionRepository;
  late final ParticipantRiskReportQueryRepository? _recipientReportsRepository;

  void _updateUi(VoidCallback update) => setState(update);

  User? get _authenticatedUser {
    try {
      return Supabase.instance.client.auth.currentUser;
    } on AssertionError {
      // Isolated widget tests and previews can mount before app bootstrap.
      return null;
    }
  }

  bool get _usesRouteSimulation =>
      DriverActiveDeliveryTrackingPolicy.usesRouteSimulation(
        isWeb: kIsWeb,
        locationMode: ref.read(driverLocationModeProvider),
        isTrafficDemo: _currentOrder.trafficDemoKey != null,
      );

  bool get _ownsDeliveryNavigation =>
      !_currentOrder.isRecipientHeld &&
      const {
        'assigned',
        'picking_up',
        'delivering',
      }.contains(_currentOrder.status) &&
      _navSessionsNotifier.sessionFor(_currentOrder.id)?.status != 'returning';

  bool get _canSimulateMovement =>
      _simulationRequested &&
      _navigationOwner.state == _currentOrder.id &&
      (_currentOrder.trafficDemoKey == null || _speedProfile != null) &&
      _ownsDeliveryNavigation &&
      DriverDeliveryWorkflow.canSimulateMovement(
        status: _currentOrder.status,
        pickupConfirmed: _pickupConfirmed,
        arrivedAtTarget: _arrivedAtTarget,
        routeCompleted: _routeCompleted,
      );

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _driverPos = ref.read(driverPhysicalPositionProvider);
    _pickupConfirmed =
        widget.order.status == 'picking_up' &&
        widget.order.actualPickedUpAt != null;
    _riskInterventionRepository =
        widget.riskInterventionRepository ?? _createRiskRepository();
    _recipientReportsRepository = _createRecipientReportsRepository();
    _navigationOwner = ref.read(activeDriverNavigationOrderProvider.notifier);
    _navigationLocationMode = ref.read(driverLocationModeProvider.notifier);
    _navSessionsNotifier = ref.read(driverNavSessionsProvider.notifier);
    _restoreNavSession();
    _restoreArrivalFromDriverFix();
    _startRouteRefresh();
    _monitoringHeartbeatTimer = Timer.periodic(const Duration(seconds: 15), (
      _,
    ) {
      unawaited(
        _publishMonitoringHeartbeat().catchError((Object error) {
          debugPrint('[DriverMonitoring] fresh position unavailable: $error');
        }),
      );
    });
    final orderId = _currentOrder.id;
    // Riverpod không cho phép đổi provider trong initState/build.
    // Future chạy sau khi frame mount hoàn tất, rồi mới bootstrap navigation.
    Future<void>(() {
      if (!mounted || _currentOrder.id != orderId) return;
      ref.read(driverPriorityOrderIdProvider.notifier).state = orderId;
      _navigationOwner.state = orderId;
      unawaited(_ensureInitialRoute());
      unawaited(_ensureDeliveryDeadline());
    });
  }

  RiskInterventionRepository? _createRiskRepository() {
    try {
      return SupabaseRiskInterventionRepository();
    } on AssertionError {
      // Widget tests and isolated previews may mount without app bootstrap.
      return null;
    }
  }

  ParticipantRiskReportQueryRepository? _createRecipientReportsRepository() {
    try {
      return SupabaseParticipantRiskReportQueryRepository();
    } on AssertionError {
      return null;
    }
  }

  Future<void> _ensureInitialRoute() async {
    final id = _currentOrder.id;
    await _navSessionsNotifier.ready;
    if (!mounted || _currentOrder.id != id) return;
    _restoreNavSession();
    await _seedDriverPosition();
    if (!mounted || _currentOrder.id != id) return;
    _applySharedPosition(ref.read(driverPhysicalPositionProvider));
    if (!_isRouting) {
      _lastRouteStatus = null;
      await _loadRoute();
    }
  }

  @override
  void didUpdateWidget(covariant DriverNavigationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id) {
      _persistNavSession();
      _simTimer?.cancel();
      ++_routeKey;
      _currentOrder = widget.order;
      _driverPos = ref.read(driverPhysicalPositionProvider);
      _routePoints = null;
      _navigationSteps = const [];
      _isRouting = false;
      _routeFailed = false;
      _simulationRequested = false;
      _lastRouteStatus = null;
      _totalDistance = null;
      _totalDuration = null;
      _pickupConfirmed =
          _currentOrder.status == 'picking_up' &&
          _currentOrder.actualPickedUpAt != null;
      _restoreNavSession();
      _restoreArrivalFromDriverFix();
      final id = _currentOrder.id;
      Future<void>(() {
        if (!mounted || _currentOrder.id != id) return;
        ref.read(driverPriorityOrderIdProvider.notifier).state = id;
        _navigationOwner.state = id;
        unawaited(_ensureInitialRoute());
      });
      return;
    }
    if (widget.order.estimatedDeliveryAt != null &&
        widget.order.estimatedDeliveryAt != _currentOrder.estimatedDeliveryAt) {
      _currentOrder = _currentOrder.copyWith(
        estimatedDeliveryAt: widget.order.estimatedDeliveryAt,
      );
    }
    if (oldWidget.order.status != widget.order.status) {
      _simulationRequested = false;
      _simTimer?.cancel();
      _currentOrder = widget.order.copyWith(
        estimatedDeliveryAt: _currentOrder.estimatedDeliveryAt,
      );
      _lastRouteStatus = null;
      ++_routeKey;
      _isRouting = false;
      _routePoints = null;
      _navigationSteps = const [];
      _arrivedAtTarget =
          false; // Reset trạng thái đến nơi để kiểm tra cho chặng tiếp theo
      _routeCompleted = false;
      _pickupConfirmed =
          widget.order.status == 'picking_up' &&
          widget.order.actualPickedUpAt != null;
      _simRouteIndex = 0;
      _loadRoute();
    }
  }

  @override
  void dispose() {
    final orderId = _currentOrder.id;
    // Không đổi provider trực tiếp trong dispose; tránh Riverpod lifecycle error.
    Future<void>(() {
      if (_navigationOwner.mounted && _navigationOwner.state == orderId) {
        _navigationOwner.state = null;
      }
    });
    if (!_exitingForOrderCancellation) _persistNavSession();
    _routeRefreshTimer?.cancel();
    _simTimer?.cancel();
    super.dispose();
    _monitoringHeartbeatTimer?.cancel();
  }

  void _advanceNavigationStep(LatLng current) {
    final nextIndex = DriverNavigationRouteLogic.advanceNavigationStepIndex(
      steps: _navigationSteps,
      currentIndex: _activeNavigationStepIndex,
      driverPosition: current,
    );
    if (nextIndex == _activeNavigationStepIndex || !mounted) return;
    setState(() => _activeNavigationStepIndex = nextIndex);
  }

  void _followCamera(LatLng position, {bool force = false}) {
    final previous = _lastCameraFollowPosition;
    final moved = previous == null
        ? double.infinity
        : const Distance().as(LengthUnit.Meter, previous, position);
    final elapsed = DateTime.now().difference(_lastCameraFollowAt);
    if (!force && (elapsed < const Duration(milliseconds: 350) || moved < 4)) {
      return;
    }
    _lastCameraFollowAt = DateTime.now();
    _lastCameraFollowPosition = position;
    DriverNavigationRouteLogic.followDriverCamera(
      controller: _mapController,
      order: _currentOrder,
      driverPosition: position,
      routePoints: _routePoints,
    );
  }

  void _fitMapBounds() {
    DriverNavigationRouteLogic.fitMapBounds(
      controller: _mapController,
      order: _currentOrder,
      driverPosition: _driverPos,
      routePoints: _routePoints,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      driverPhysicalPositionProvider,
      (_, next) => _applySharedPosition(next),
    );
    ref.listen(
      driverArrivalFixProvider,
      (_, _) => _applySharedPosition(ref.read(driverPhysicalPositionProvider)),
    );
    _driverPos = ref.watch(driverPhysicalPositionProvider);
    if (_authenticatedUser != null) {
      final data = ref
          .watch(orderEtaProvider(_currentOrder.id))
          .valueOrNull
          ?.data;
      if (data != null &&
          data['driver_id'] == _currentOrder.driverId &&
          data['computed_at'] !=
              _currentOrder.deliveryEtaData?['computed_at']) {
        _currentOrder = _currentOrder.copyWith(deliveryEtaData: data);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _lastRouteStatus = null;
            unawaited(_loadRoute());
          }
        });
      }
    }
    final order = _currentOrder;
    final navigationStep = DriverNavigationRouteLogic.nextNavigationStep(
      steps: _navigationSteps,
      activeIndex: _activeNavigationStepIndex,
    );
    final maneuverDistance = navigationStep == null || _driverPos == null
        ? null
        : const Distance().as(
            LengthUnit.Meter,
            _driverPos!,
            navigationStep.location,
          );
    final center =
        _driverPos ??
        LatLng(
          (order.pickupLat + order.deliveryLat) / 2,
          (order.pickupLng + order.deliveryLng) / 2,
        );

    final view = DriverNavigationView(
      monitoringPanel: _authenticatedUser == null
          ? null
          : DriverMonitoringPanel(
              orderId: order.id,
              pickupArrivedAt: order.pickupArrivedAt,
              holdingGoods:
                  _pickupConfirmed ||
                  order.actualPickedUpAt != null ||
                  order.status == 'delivering',
              onRecover: _recoverMonitoringGps,
            ),
      onReturnCancelled: _resumeAfterReturnCancelled,
      showMapStart: _usesRouteSimulation,
      simulationRunning: _canSimulateMovement,
      onStopSimulation: _stopSimulationFromMap,
      onStartSimulation:
          _routePoints != null &&
              _routePoints!.length >= 2 &&
              _ownsDeliveryNavigation &&
              (order.trafficDemoKey == null || _speedProfile != null) &&
              DriverDeliveryWorkflow.canSimulateMovement(
                status: order.status,
                pickupConfirmed: _pickupConfirmed,
                arrivedAtTarget: _arrivedAtTarget,
                routeCompleted: _routeCompleted,
              )
          ? _startSimulationFromMap
          : null,
      showOrderDetails: true,
      order: order,
      totalDistance: _totalDistance,
      totalDuration: _totalDuration,
      driverLatitude: _driverPos?.latitude,
      driverLongitude: _driverPos?.longitude,
      arrivedAtTarget: _arrivedAtTarget,
      routeCompleted: _routeCompleted,
      pickupConfirmed: _pickupConfirmed,
      isUpdatingStatus: _isUpdatingStatus,
      navigationStep: navigationStep,
      maneuverDistance: maneuverDistance,
      onBack: () => Navigator.of(context).maybePop(),
      onFitMap: _fitMapBounds,
      onPrimaryAction: _handlePrimaryAction,
      onConfirmPickupArrival: _confirmPickupArrival,
      onPrepareDeliveryArrival: _prepareDeliveryArrival,
      onHoldOrder:
          order.status == 'delivering' &&
              order.recipientHold == null &&
              _arrivedAtTarget
          ? _holdOrder
          : null,
      onReportRecipient: _reportUnreachableRecipient,
      onContact: _openActiveOrderContact,
      currentUserId: _authenticatedUser?.id,
      onOpenMessageChat: _openOrderChat,
      riskInterventionRepository: _riskInterventionRepository,
      onDriverReleased: _handleSupportCancellation,
      onOrderCancelled: _handleDriverOrderCancellation,
      recipientReportsRepository: _recipientReportsRepository,
      map: DriverNavigationMap(
        tileProvider: ref.watch(driverNavigationTilesProvider),
        mapController: _mapController,
        order: order,
        center: center,
        routePoints: _routePoints,
        driverPosition: _driverPos,
        otherDestination: _otherTaskDestination(),
        status: _driverPos == null
            ? DriverNavigationLocationStrings.locating
            : _isRouting
            ? DriverNavigationLocationStrings.routing
            : _routeFailed
            ? DriverNavigationLocationStrings.routeUnavailable
            : !_hasFreshDriverFix
            ? DriverNavigationLocationStrings.lastKnown
            : null,
      ),
    );
    return DriverMonitoringGuard(
      orderId: order.id,
      pickupArrivedAt: order.pickupArrivedAt,
      enabled: _authenticatedUser != null,
      onReleased: _handleMonitoringRelease,
      child: view,
    );
  }
}
