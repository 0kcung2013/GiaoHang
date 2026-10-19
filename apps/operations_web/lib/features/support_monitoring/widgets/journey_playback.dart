import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:latlong2/latlong.dart';
import '../../risk_reports/models/risk_journey.dart';
import '../../risk_reports/constants/risk_journey_strings.dart';
import '../constants/journey_strings.dart';

class JourneyPlayback extends StatefulWidget {
  const JourneyPlayback({
    required this.order,
    required this.journey,
    required this.mapHeight,
    this.tileProvider,
    super.key,
  });
  final RiskOrderSummary order;
  final RiskJourney journey;
  final double mapHeight;
  final TileProvider? tileProvider;
  @override
  State<JourneyPlayback> createState() => _JourneyPlaybackState();
}

class _JourneyPlaybackState extends State<JourneyPlayback> {
  final _map = MapController();
  Timer? _timer;
  late int _index = widget.journey.points.length - 1;
  bool get _playing => _timer != null;

  List<LatLng> get _stops => [
    if (widget.order.pickupLat != null && widget.order.pickupLng != null)
      LatLng(widget.order.pickupLat!, widget.order.pickupLng!),
    if (widget.order.deliveryLat != null && widget.order.deliveryLng != null)
      LatLng(widget.order.deliveryLat!, widget.order.deliveryLng!),
  ];

  List<LatLng> get _bounds => [
    ..._stops,
    ...widget.journey.points.map((p) => p.position),
  ];

  // Open on the most recent continuous trace. An older disconnected fix must
  // not force the initial view out to an entire city. All samples remain
  // available through playback and the full-journey camera control.
  List<LatLng> get _latestBounds => [
    ..._stops,
    ...widget.journey.segments.last,
  ];

  CameraFit _cameraFit(List<LatLng> coordinates) => CameraFit.coordinates(
    coordinates: coordinates,
    padding: const EdgeInsets.all(48),
    maxZoom: 17,
  );

  void _showLatest() {
    _timer?.cancel();
    setState(() {
      _timer = null;
      _index = widget.journey.points.length - 1;
    });
    _map.fitCamera(_cameraFit(_latestBounds));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _map.dispose();
    super.dispose();
  }

  void _select(int index) {
    setState(() => _index = index);
    _map.move(widget.journey.points[index].position, _map.camera.zoom);
  }

  void _toggle() {
    if (_playing) {
      _timer!.cancel();
      setState(() => _timer = null);
      return;
    }
    if (_index == widget.journey.points.length - 1) _select(0);
    setState(
      () => _timer = Timer.periodic(const Duration(milliseconds: 650), (_) {
        if (_index == widget.journey.points.length - 1) {
          _toggle();
        } else {
          _select(_index + 1);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.journey.points;
    final latest = _index == points.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latest
                          ? JourneyStrings.latestGps
                          : JourneyStrings.selectedGps,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      RiskJourneyStrings.formatTime(points[_index].time),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: JourneyStrings.showLatest,
                onPressed: _showLatest,
                icon: const Icon(Icons.my_location_rounded),
                color: AppColors.primary,
              ),
            ],
          ),
        ),
        SizedBox(
          height: widget.mapHeight,
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: points.last.position,
              initialZoom: 17,
              initialCameraFit: _latestBounds.length > 1
                  ? _cameraFit(_latestBounds)
                  : null,
            ),
            children: [
              TileLayer(
                tileProvider: widget.tileProvider,
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.datn.giaohang.operations',
              ),
              PolylineLayer(
                polylines: [
                  for (final segment in widget.journey.segments)
                    if (segment.length > 1)
                      Polyline(
                        points: segment,
                        color: AppColors.routeLine,
                        strokeWidth: 4,
                      ),
                ],
              ),
              MarkerLayer(
                markers: [
                  if (widget.order.pickupLat != null &&
                      widget.order.pickupLng != null)
                    _marker(
                      LatLng(widget.order.pickupLat!, widget.order.pickupLng!),
                      Icons.inventory_2_outlined,
                      AppColors.markerPickup,
                      RiskJourneyStrings.pickup,
                    ),
                  if (widget.order.deliveryLat != null &&
                      widget.order.deliveryLng != null)
                    _marker(
                      LatLng(
                        widget.order.deliveryLat!,
                        widget.order.deliveryLng!,
                      ),
                      Icons.flag_rounded,
                      AppColors.markerDrop,
                      RiskJourneyStrings.delivery,
                    ),
                  _marker(
                    points[_index].position,
                    Icons.navigation_rounded,
                    AppColors.primary,
                    latest
                        ? JourneyStrings.latestGps
                        : JourneyStrings.selectedGps,
                  ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
              Positioned(
                right: AppSpacing.md,
                top: AppSpacing.md,
                child: Material(
                  color: AppColors.bgCard,
                  borderRadius: AppRadius.md,
                  elevation: 2,
                  child: IconButton(
                    tooltip: JourneyStrings.fit,
                    icon: const Icon(Icons.fit_screen_rounded),
                    onPressed: () => _map.fitCamera(_cameraFit(_bounds)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: points.length > 1 ? _toggle : null,
                    icon: Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      _playing ? JourneyStrings.pause : JourneyStrings.play,
                    ),
                  ),
                  Text(
                    RiskJourneyStrings.formatTime(points[_index].time),
                    style: AppTextStyles.labelMedium,
                  ),
                ],
              ),
              if (points.length > 1)
                Slider(
                  value: _index.toDouble(),
                  max: (points.length - 1).toDouble(),
                  activeColor: AppColors.info,
                  semanticFormatterCallback: (value) =>
                      RiskJourneyStrings.formatTime(points[value.round()].time),
                  onChanged: (value) {
                    if (_playing) _toggle();
                    _select(value.round());
                  },
                ),
              Text(
                RiskJourneyStrings.legend,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (widget.journey.unavailableChunks > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    RiskJourneyStrings.partial(
                      widget.journey.unavailableChunks,
                    ),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Marker _marker(LatLng position, IconData icon, Color color, String label) =>
      Marker(
        point: position,
        width: 40,
        height: 40,
        child: Tooltip(
          message: label,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: AppRadius.full,
              border: Border.all(color: color, width: 2),
              boxShadow: AppShadow.subtle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      );
}
