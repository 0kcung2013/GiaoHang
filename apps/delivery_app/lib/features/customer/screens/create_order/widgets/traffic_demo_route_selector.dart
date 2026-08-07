import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../models/traffic_demo_scenario.dart';
import 'traffic_demo_route_card.dart';

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
    return Row(
      children: [
        for (final scenario in scenarios) ...[
          Expanded(
            child: TrafficDemoRouteCard(
              scenario: scenario,
              isApplied: selectedId == scenario.id,
              onApply: () => onApply(scenario),
            ),
          ),
          if (scenario != scenarios.last) const SizedBox(width: AppSpacing.xs),
        ],
      ],
    );
  }
}
