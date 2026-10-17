import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../utils/delivery_traffic_route_analyzer.dart';
import '../constants/eta_simulation_strings.dart';
import '../ml/eta_simulation/coverage.dart';

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
    final synthetic = segments.any((segment) => segment.isSynthetic);
    final speedColors = segments.any((segment) => segment.usesSpeedColors);
    final unavailableLabel =
        segments.any(
          (s) => s.fallbackReason == EtaSimulationCoverage.outsideReason,
        )
        ? EtaSimulationStrings.outsideCoverage
        : EtaSimulationStrings.routingEstimate;
    final semanticsLabel = synthetic && hasHistorical
        ? speedColors
              ? EtaSimulationStrings.legendSemantics
              : EtaSimulationStrings.legacyLegendSemantics
        : hasHistorical
        ? 'Vận tốc AI dự báo: xanh trên 40, vàng 34 đến 40, cam 28 đến 34, đỏ dưới 28 km/h${hasUnavailable ? ', xanh dương là phần chưa có dự báo' : ''}'
        : synthetic
        ? EtaSimulationStrings.unlocalized
        : unavailableLabel;

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
                            synthetic
                                ? speedColors
                                      ? EtaSimulationStrings.legendTitle
                                      : EtaSimulationStrings.legacyLegendTitle
                                : 'Vận tốc theo tuyến',
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
                        _LegendItem(
                          level: DeliveryTrafficLevel.clear,
                          label: synthetic
                              ? speedColors
                                    ? EtaSimulationStrings.clear
                                    : EtaSimulationStrings.legacyClear
                              : '>40 km/h',
                        ),
                        _LegendItem(
                          level: DeliveryTrafficLevel.moderate,
                          label: synthetic
                              ? speedColors
                                    ? EtaSimulationStrings.moderate
                                    : EtaSimulationStrings.legacyModerate
                              : '34–40 km/h',
                        ),
                        _LegendItem(
                          level: DeliveryTrafficLevel.heavy,
                          label: synthetic
                              ? speedColors
                                    ? EtaSimulationStrings.heavy
                                    : EtaSimulationStrings.legacyHeavy
                              : '28–34 km/h',
                        ),
                        _LegendItem(
                          level: DeliveryTrafficLevel.congested,
                          label: synthetic
                              ? speedColors
                                    ? EtaSimulationStrings.congested
                                    : EtaSimulationStrings.legacyCongested
                              : '<28 km/h',
                        ),
                        if (hasUnavailable)
                          _LegendItem(
                            level: DeliveryTrafficLevel.unavailable,
                            label: synthetic
                                ? EtaSimulationStrings.unavailable
                                : 'Ngoài vùng',
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
                        synthetic
                            ? EtaSimulationStrings.unlocalized
                            : unavailableLabel,
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
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
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
