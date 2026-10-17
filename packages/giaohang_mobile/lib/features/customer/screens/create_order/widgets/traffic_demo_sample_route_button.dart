import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../utils/traffic_demo_strings.dart';

class TrafficDemoSampleRouteButton extends StatelessWidget {
  const TrafficDemoSampleRouteButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: TrafficDemoStrings.sampleRouteLabel,
    hint: TrafficDemoStrings.sampleRouteHint,
    child: Material(
      color: AppColors.info.withValues(alpha: 0.05),
      borderRadius: AppRadius.md,
      child: InkWell(
        key: const ValueKey('traffic-demo-sample-route'),
        onTap: onPressed,
        borderRadius: AppRadius.md,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.info.withValues(alpha: 0.24)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.alt_route_rounded,
                size: 20,
                color: AppColors.info,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  TrafficDemoStrings.sampleRouteLabel,
                  maxLines: 2,
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.refresh_rounded,
                size: 17,
                color: AppColors.info,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
