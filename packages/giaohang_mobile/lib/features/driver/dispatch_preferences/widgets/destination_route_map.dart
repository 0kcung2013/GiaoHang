import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/osrm_service.dart';
import '../dispatch_preferences_strings.dart';

class DestinationRouteMap extends StatefulWidget {
  const DestinationRouteMap({
    super.key,
    required this.origin,
    this.destination,
    this.onTap,
    this.height = 280,
  });
  final LatLng? origin;
  final LatLng? destination;
  final ValueChanged<LatLng>? onTap;
  final double height;
  @override
  State<DestinationRouteMap> createState() => _DestinationRouteMapState();
}

class _DestinationRouteMapState extends State<DestinationRouteMap> {
  Future<OsrmRouteResult?>? _route;
  LatLng? _lastOrigin;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DestinationRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.destination != oldWidget.destination ||
        (widget.origin == null && oldWidget.origin != null) ||
        _lastOrigin == null ||
        (widget.origin != null &&
            const Distance().as(
                  LengthUnit.Meter,
                  _lastOrigin!,
                  widget.origin!,
                ) >
                100)) {
      _load();
    }
  }

  void _load() {
    _lastOrigin = widget.origin;
    final target = widget.destination;
    _route = target == null || widget.origin == null
        ? null
        : OsrmService().getRoute(
            startLat: widget.origin!.latitude,
            startLng: widget.origin!.longitude,
            endLat: target.latitude,
            endLng: target.longitude,
          );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<OsrmRouteResult?>(
    future: _route,
    builder: (context, snapshot) {
      final target = widget.destination;
      final points = snapshot.connectionState == ConnectionState.done
          ? snapshot.data?.points ?? const <LatLng>[]
          : const <LatLng>[];
      return Column(
        children: [
          ClipRRect(
            borderRadius: AppRadius.lg,
            child: SizedBox(
              height: widget.height,
              child: FlutterMap(
                key: ValueKey(target),
                options: MapOptions(
                  initialCenter:
                      target ?? widget.origin ?? const LatLng(10.98, 106.65),
                  initialZoom: 12,
                  initialCameraFit: target == null || widget.origin == null
                      ? null
                      : CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints([
                            if (widget.origin != null) widget.origin!,
                            target,
                            ...points,
                          ]),
                          padding: const EdgeInsets.all(32),
                          maxZoom: 16,
                        ),
                  onTap: (_, point) => widget.onTap?.call(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.datn.giaohang',
                  ),
                  if (points.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: points,
                          color: AppColors.routeLine,
                          strokeWidth: 5,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (widget.origin != null)
                        Marker(
                          point: widget.origin!,
                          child: const Icon(
                            Icons.my_location_rounded,
                            color: AppColors.markerDriver,
                            size: 32,
                          ),
                        ),
                      if (target != null)
                        Marker(
                          point: target,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.markerDrop,
                            size: 40,
                          ),
                        ),
                    ],
                  ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (target != null &&
              widget.origin != null &&
              snapshot.connectionState == ConnectionState.waiting)
            const LinearProgressIndicator(),
          if (target != null &&
              snapshot.connectionState == ConnectionState.done &&
              snapshot.data == null)
            TextButton.icon(
              onPressed: () => setState(_load),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(DispatchPreferencesStrings.routeError),
            ),
        ],
      );
    },
  );
}
