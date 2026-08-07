import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../utils/delivery_traffic_route_analyzer.dart';

class DeliveryTrafficRouteLayer extends StatelessWidget {
  const DeliveryTrafficRouteLayer({
    super.key,
    required this.segments,
    this.strokeWidth = 6,
  });

  final List<DeliveryTrafficSegment> segments;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return PolylineLayer(
      polylines: [
        for (final segment in segments)
          Polyline(
            points: segment.points,
            color: deliveryTrafficColor(segment.level),
            strokeWidth: strokeWidth,
          ),
      ],
    );
  }
}

class DeliveryTrafficMapLegend extends StatelessWidget {
  const DeliveryTrafficMapLegend({super.key, required this.segments});

  final List<DeliveryTrafficSegment> segments;

  @override
  Widget build(BuildContext context) {
    final hasHistorical = segments.hasHistoricalTraffic;
    final hasUnavailable = segments.hasUnavailableTraffic;
    final semanticsLabel = hasHistorical
        ? 'Màu giao thông lịch sử UTraffic: xanh thông thoáng, vàng đông, cam di chuyển chậm, đỏ hay ùn tắc${hasUnavailable ? ', xanh dương là ngoài vùng dữ liệu' : ''}'
        : 'Tuyến OSRM ngoài vùng dữ liệu giao thông UTraffic';

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.bgCard.withValues(alpha: 0.95),
            borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadow.card,
          ),
          child: hasHistorical
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 15,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            'UTraffic · dự báo lịch sử',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        const _LegendItem(
                          level: DeliveryTrafficLevel.clear,
                          label: 'Thoáng',
                        ),
                        const _LegendItem(
                          level: DeliveryTrafficLevel.moderate,
                          label: 'Đông',
                        ),
                        const _LegendItem(
                          level: DeliveryTrafficLevel.heavy,
                          label: 'Di chuyển chậm',
                        ),
                        const _LegendItem(
                          level: DeliveryTrafficLevel.congested,
                          label: 'Hay tắc',
                        ),
                        if (hasUnavailable)
                          const _LegendItem(
                            level: DeliveryTrafficLevel.unavailable,
                            label: 'Ngoài vùng',
                          ),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.route_outlined,
                      size: 16,
                      color: AppColors.routeLine,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        'Ngoài vùng UTraffic · tuyến OSRM',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.level, required this.label});

  final DeliveryTrafficLevel level;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 15,
          height: 5,
          decoration: BoxDecoration(
            color: deliveryTrafficColor(level),
            borderRadius: AppRadius.full,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

Color deliveryTrafficColor(DeliveryTrafficLevel level) {
  return switch (level) {
    DeliveryTrafficLevel.clear => AppColors.success,
    DeliveryTrafficLevel.moderate => AppColors.warning,
    DeliveryTrafficLevel.heavy => AppColors.accent,
    DeliveryTrafficLevel.congested => AppColors.error,
    DeliveryTrafficLevel.unavailable => AppColors.routeLine,
  };
}
