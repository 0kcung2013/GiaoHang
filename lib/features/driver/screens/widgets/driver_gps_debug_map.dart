import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_theme.dart';

class DriverGpsDebugMap extends StatelessWidget {
  const DriverGpsDebugMap({
    super.key,
    required this.gpsPosition,
    required this.demoPosition,
    required this.hasOffset,
  });

  final LatLng gpsPosition;
  final LatLng demoPosition;
  final bool hasOffset;

  @override
  Widget build(BuildContext context) {
    final center = LatLng(
      (gpsPosition.latitude + demoPosition.latitude) / 2,
      (gpsPosition.longitude + demoPosition.longitude) / 2,
    );

    return Semantics(
      label: hasOffset
          ? 'Bản đồ so sánh GPS thật và vị trí demo'
          : 'Bản đồ vị trí GPS hiện tại',
      child: Container(
        height: 224,
        decoration: BoxDecoration(
          color: AppColors.bgLight,
          borderRadius: AppRadius.xl,
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: hasOffset ? 12.5 : 15.5,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.datn.giaohang',
                  maxNativeZoom: 19,
                ),
                if (hasOffset)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [gpsPosition, demoPosition],
                        color: AppColors.accent.withValues(alpha: 0.7),
                        strokeWidth: 3,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: gpsPosition,
                      width: 48,
                      height: 48,
                      child: const _MapPin(
                        icon: Icons.my_location_rounded,
                        color: AppColors.info,
                      ),
                    ),
                    if (hasOffset)
                      Marker(
                        point: demoPosition,
                        width: 48,
                        height: 48,
                        child: const _MapPin(
                          icon: Icons.local_shipping_rounded,
                          color: AppColors.accent,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.bgCard.withValues(alpha: 0.94),
                  borderRadius: AppRadius.md,
                  boxShadow: AppShadow.subtle,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.xs,
                    children: [
                      const _LegendItem(
                        color: AppColors.info,
                        label: 'GPS thiết bị',
                      ),
                      if (hasOffset)
                        const _LegendItem(
                          color: AppColors.accent,
                          label: 'Vị trí demo',
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.bgCard, width: 3),
        boxShadow: AppShadow.card,
      ),
      child: Icon(icon, color: AppColors.textOnAccent, size: 22),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
