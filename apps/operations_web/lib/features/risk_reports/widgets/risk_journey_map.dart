import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../models/risk_report.dart';
import '../models/risk_journey.dart';
import '../constants/risk_journey_strings.dart';

class RiskJourneyMap extends StatefulWidget {
  RiskJourneyMap({
    required RiskReport report,
    required this.journey,
    this.tileProvider,
    super.key,
  }) : order = report.order,
       eventTime = report.createdAt;
  const RiskJourneyMap.forOrder({
    required this.order,
    required this.eventTime,
    required this.journey,
    this.tileProvider,
    super.key,
  });
  final RiskOrderSummary order;
  final DateTime eventTime;
  final RiskJourney journey;
  final TileProvider? tileProvider;
  @override
  State<RiskJourneyMap> createState() => _RiskJourneyMapState();
}

class _RiskJourneyMapState extends State<RiskJourneyMap> {
  final controller = MapController();
  late int selected = widget.journey.closestIndex(widget.eventTime);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final points = widget.journey.points;
    final pickup = order.pickupLat == null || order.pickupLng == null
        ? null
        : LatLng(order.pickupLat!, order.pickupLng!);
    final drop = order.deliveryLat == null || order.deliveryLng == null
        ? null
        : LatLng(order.deliveryLat!, order.deliveryLng!);
    final bounds = [?pickup, ?drop, ...points.map((p) => p.position)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          RiskJourneyStrings.summary(
            points.length,
            widget.journey.segments.length,
          ),
          style: AppTextStyles.labelMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: FlutterMap(
            mapController: controller,
            options: MapOptions(
              initialCenter: bounds.isEmpty
                  ? const LatLng(10.776, 106.7)
                  : bounds.first,
              initialZoom: 15,
              initialCameraFit: bounds.length > 1
                  ? CameraFit.coordinates(
                      coordinates: bounds,
                      padding: const EdgeInsets.all(48),
                      maxZoom: 17,
                    )
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
                        strokeWidth: 5,
                      ),
                ],
              ),
              MarkerLayer(
                markers: [
                  if (pickup != null)
                    _marker(
                      pickup,
                      Icons.inventory_2_rounded,
                      AppColors.markerPickup,
                      RiskJourneyStrings.pickup,
                    ),
                  if (drop != null)
                    _marker(
                      drop,
                      Icons.flag_rounded,
                      AppColors.markerDrop,
                      RiskJourneyStrings.delivery,
                    ),
                  if (points.isNotEmpty)
                    _marker(
                      points[selected].position,
                      Icons.navigation_rounded,
                      AppColors.markerDriver,
                      RiskJourneyStrings.selected,
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
        if (points.isNotEmpty) ...[
          Text(
            RiskJourneyStrings.timeline(
              points[selected].time,
              points.last.time,
            ),
            style: AppTextStyles.bodySmall,
          ),
          if (points.length > 1)
            Slider(
              value: selected.toDouble(),
              max: (points.length - 1).toDouble(),
              divisions: points.length - 1,
              activeColor: AppColors.accent,
              onChanged: (value) {
                setState(() => selected = value.round());
                controller.move(
                  points[selected].position,
                  controller.camera.zoom,
                );
              },
            ),
        ],
        Text(RiskJourneyStrings.legend, style: AppTextStyles.bodySmall),
        if (widget.journey.unavailableChunks > 0)
          Text(
            RiskJourneyStrings.partial(widget.journey.unavailableChunks),
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
          ),
      ],
    );
  }

  Marker _marker(LatLng point, IconData icon, Color color, String label) =>
      Marker(
        point: point,
        width: 44,
        height: 44,
        child: Tooltip(
          message: label,
          child: Icon(icon, color: color, size: 32),
        ),
      );
}
