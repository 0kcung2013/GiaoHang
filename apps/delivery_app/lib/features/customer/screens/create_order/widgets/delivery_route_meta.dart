import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../utils/order_form_data.dart';

class DeliveryRouteMeta extends StatelessWidget {
  const DeliveryRouteMeta({super.key, required this.data});

  final OrderFormData data;

  @override
  Widget build(BuildContext context) {
    final eta = data.deliveryEta;
    final routeBasis = eta.usedAiCorrection
        ? eta.usedRouteDuration
              ? 'AI TP.HCM + OSRM'
              : 'AI TP.HCM + khoảng cách'
        : eta.usedRouteDuration
        ? 'OSRM + ETA dự phòng'
        : 'ETA dự phòng theo vận tốc đô thị';

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _MetaChip(
          icon: Icons.route_outlined,
          label: '${data.distanceKm.toStringAsFixed(1)} km đường bộ',
        ),
        _MetaChip(icon: Icons.tune_rounded, label: routeBasis),
        const _MetaChip(
          icon: Icons.person_search_outlined,
          label: 'Tìm tài xế tối đa 15 phút',
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.07),
        borderRadius: AppRadius.full,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.info),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
