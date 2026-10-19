import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'journey_status.dart';
import '../constants/journey_strings.dart';
import '../models/archived_journey_order.dart';

class JourneyOrderCard extends StatelessWidget {
  const JourneyOrderCard({
    required this.item,
    required this.selected,
    required this.onTap,
    super.key,
  });
  final ArchivedJourneyOrder item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: Material(
      color: selected
          ? AppColors.info.withValues(alpha: .06)
          : AppColors.bgCard,
      borderRadius: AppRadius.lg,
      child: InkWell(
        key: ValueKey('journey-order-${item.order.id}'),
        borderRadius: AppRadius.lg,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lg,
            border: Border.all(
              color: selected ? AppColors.info : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.order.trackingCode.isEmpty
                          ? item.order.id
                          : item.order.trackingCode,
                      style: AppTextStyles.headingSmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.chevron_right_rounded,
                    color: selected ? AppColors.info : AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              JourneyStatus(status: item.order.status),
              const SizedBox(height: AppSpacing.lg),
              _Address(
                icon: Icons.trip_origin_rounded,
                color: AppColors.markerPickup,
                text: item.order.pickupAddress,
              ),
              const SizedBox(height: AppSpacing.sm),
              _Address(
                icon: Icons.location_on_outlined,
                color: AppColors.markerDrop,
                text: item.order.deliveryAddress,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      JourneyStrings.archive,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '${item.archive.lastDay.day}/${item.archive.lastDay.month}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Address extends StatelessWidget {
  const _Address({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    ],
  );
}
