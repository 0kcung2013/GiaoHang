import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/osrm_service.dart';
import '../driver/screens/navigation/utils/driver_navigation_route_logic.dart';
import 'models/return_map_snapshot.dart';
import 'utils/return_navigation_strings.dart';
import 'widgets/return_navigation_map.dart';
import 'widgets/return_map_overlay.dart';

/// Bản đồ riêng: chỉ dẫn và Start; mọi xác nhận đơn ở màn hình cha.
class ReturnMapScreen extends StatefulWidget {
  const ReturnMapScreen({
    required this.snapshot,
    required this.destination,
    required this.isReturnRoute,
    required this.onStart,
    super.key,
  });

  final ValueListenable<ReturnMapSnapshot> snapshot;
  final LatLng destination;
  final bool isReturnRoute;
  final VoidCallback onStart;

  @override
  State<ReturnMapScreen> createState() => _ReturnMapScreenState();
}

class _ReturnMapScreenState extends State<ReturnMapScreen> {
  final _controller = MapController();
  OsrmRouteResult? _preview;
  bool _previewLoading = false;
  bool _previewFailed = false;
  bool _mapReady = false;
  bool _hasFit = false;

  @override
  void initState() {
    super.initState();
    widget.snapshot.addListener(_onSnapshotChanged);
    if (!widget.isReturnRoute) _loadPreview();
  }

  @override
  void dispose() {
    widget.snapshot.removeListener(_onSnapshotChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    final origin = widget.snapshot.value.position;
    setState(() {
      _previewLoading = true;
      _previewFailed = false;
    });
    try {
      final route = origin == null
          ? null
          : await OsrmService().getRoute(
              startLat: origin.latitude,
              startLng: origin.longitude,
              endLat: widget.destination.latitude,
              endLng: widget.destination.longitude,
            );
      if (!mounted) return;
      setState(() {
        _preview = route;
        _previewFailed = route == null;
        _previewLoading = false;
        _hasFit = false;
      });
      _onSnapshotChanged();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _previewLoading = false;
        _previewFailed = true;
      });
    }
  }

  void _onSnapshotChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady) return;
      final state = widget.snapshot.value;
      final route = widget.isReturnRoute ? state.route : _preview?.points;
      // Camera chạy cùng vị trí nội suy trong ReturnNavigationMap. Không đưa
      // camera tới GPS đích trước khi icon kịp đi đến đó.
      if (!state.running && !_hasFit && route != null && route.length >= 2) {
        if (route.every(
          (point) =>
              const Distance().as(LengthUnit.Meter, route.first, point) < 1,
        )) {
          _controller.move(route.first, 17);
          _hasFit = true;
          return;
        }
        _controller.fitCamera(
          CameraFit.coordinates(
            coordinates: route,
            padding: const EdgeInsets.fromLTRB(40, 130, 40, 110),
            maxZoom: 17,
          ),
        );
        _hasFit = true;
      }
    });
  }

  void _followPosition() {
    final position = widget.snapshot.value.position;
    if (position == null) return;
    DriverNavigationRouteLogic.followRouteCamera(
      controller: _controller,
      driverPosition: position,
      routePoints: widget.isReturnRoute
          ? widget.snapshot.value.route
          : _preview?.points,
      fallbackTarget: widget.destination,
    );
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<ReturnMapSnapshot>(
        valueListenable: widget.snapshot,
        builder: (context, state, _) {
          final route = widget.isReturnRoute ? state.route : _preview?.points;
          final loading = widget.isReturnRoute
              ? state.loading
              : _previewLoading;
          final distance = widget.isReturnRoute
              ? state.distance
              : _preview?.distanceMeters;
          final duration = widget.isReturnRoute
              ? state.duration
              : _preview?.durationSeconds;
          final instruction = widget.isReturnRoute
              ? state.arrived
                    ? ReturnNavigationStrings.arrivedTitle
                    : state.step?.instruction ??
                          ReturnNavigationStrings.fallbackTitle
              : ReturnNavigationStrings.deliveryPoint;
          return Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                ReturnNavigationMap(
                  controller: _controller,
                  destination: widget.destination,
                  position: state.position,
                  route: route,
                  followPosition: widget.isReturnRoute && state.running,
                  destinationIsPickup: widget.isReturnRoute,
                  onMapReady: () {
                    _mapReady = true;
                    _onSnapshotChanged();
                  },
                ),
                ReturnMapOverlay(
                  state: state,
                  isReturnRoute: widget.isReturnRoute,
                  previewFailed: _previewFailed,
                  loading: loading,
                  distance: distance,
                  duration: duration,
                  instruction: instruction,
                  onBack: () => Navigator.of(context).pop(),
                  onStart: widget.onStart,
                  onFollow: _followPosition,
                  onRetry: _loadPreview,
                ),
              ],
            ),
          );
        },
      );
}
