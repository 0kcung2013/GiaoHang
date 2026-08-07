import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../models/traffic_demo_scenario.dart';

class TrafficDemoRouteCard extends StatelessWidget {
  const TrafficDemoRouteCard({
    super.key,
    required this.scenario,
    required this.isApplied,
    required this.onApply,
  });

  final TrafficDemoScenario scenario;
  final bool isApplied;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isApplied
          ? 'Tuyến AI mẫu đã được điền: ${scenario.title}'
          : 'Dùng tuyến AI mẫu: ${scenario.title}',
      hint: isApplied
          ? 'Chạm để điền lại hai điểm mẫu'
          : 'Chạm để tự điền điểm lấy và điểm giao phục vụ kiểm thử ETA',
      child: Material(
        color: AppColors.bgCard.withValues(alpha: 0),
        child: InkWell(
          key: ValueKey('traffic-demo-route-${scenario.id}'),
          onTap: onApply,
          borderRadius: AppRadius.md,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.06),
                borderRadius: AppRadius.md,
                border: Border.all(
                  color: isApplied
                      ? AppColors.success.withValues(alpha: 0.45)
                      : AppColors.info.withValues(alpha: 0.26),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: (isApplied ? AppColors.success : AppColors.info)
                          .withValues(alpha: 0.12),
                      borderRadius: AppRadius.full,
                    ),
                    child: Icon(
                      isApplied
                          ? Icons.check_rounded
                          : Icons.auto_awesome_rounded,
                      size: 14,
                      color: isApplied ? AppColors.success : AppColors.info,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isApplied
                              ? 'Đã chọn · ${scenario.title}'
                              : scenario.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isApplied
                        ? Icons.refresh_rounded
                        : Icons.arrow_forward_rounded,
                    size: 16,
                    color: AppColors.info,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
