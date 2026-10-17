import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../models/traffic_demo_scenario.dart';
import 'traffic_demo_time_button.dart';
import 'traffic_demo_sample_route_button.dart';

class TrafficDemoRouteSelector extends StatelessWidget {
  const TrafficDemoRouteSelector({
    super.key,
    required this.selectedId,
    required this.onApply,
    required this.onUseSampleRoute,
  });

  final String? selectedId;
  final ValueChanged<TrafficDemoScenario> onApply;
  final VoidCallback onUseSampleRoute;

  @override
  Widget build(BuildContext context) {
    final scenarios = [
      TrafficDemoScenario.hcmHistoricCongestion,
      TrafficDemoScenario.hcmHistoricClearTraffic,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TrafficDemoSampleRouteButton(onPressed: onUseSampleRoute),
        const SizedBox(height: AppSpacing.xs),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final scenario in scenarios) ...[
                Expanded(
                  child: TrafficDemoTimeButton(
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
        ),
      ],
    );
  }
}
