import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../models/traffic_demo_scenario.dart';
import 'traffic_demo_route_card.dart';
import '../utils/traffic_demo_strings.dart';

class TrafficDemoRouteSelector extends StatelessWidget {
  const TrafficDemoRouteSelector({
    super.key,
    required this.selectedId,
    required this.onApply,
  });

  final String? selectedId;
  final ValueChanged<TrafficDemoScenario> onApply;

  @override
  Widget build(BuildContext context) {
    final scenarios = [
      TrafficDemoScenario.hcmHistoricCongestion,
      TrafficDemoScenario.hcmHistoricClearTraffic,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final scenario in scenarios) ...[
              Expanded(
                child: TrafficDemoRouteCard(
                  scenario: scenario,
                  isApplied: selectedId == scenario.id,
                  onApply: () => onApply(scenario),
                ),
              ),
              if (scenario != scenarios.last)
                const SizedBox(width: AppSpacing.xs),
            ],
          ],
        ),
        if (selectedId != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            TrafficDemoStrings.forecastNote,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
