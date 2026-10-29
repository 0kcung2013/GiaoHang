import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../models/admin_snapshot.dart';
import '../utils/admin_formatters.dart';
import 'admin_surface.dart';

class AdminMetrics extends StatelessWidget {
  const AdminMetrics({
    super.key,
    required this.snapshot,
    required this.loading,
  });
  final AdminSnapshot? snapshot;
  final bool loading;
  static const _items = [
    (AdminMetric.orders, Icons.inventory_2_rounded),
    (AdminMetric.active, Icons.local_shipping_rounded),
    (AdminMetric.waiting, Icons.hourglass_top_rounded),
    (AdminMetric.delivered, Icons.task_alt_rounded),
    (AdminMetric.drivers, Icons.two_wheeler_rounded),
    (AdminMetric.customers, Icons.people_alt_rounded),
  ];
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final columns = constraints.maxWidth >= 1100 && scale < 1.3
          ? 6
          : constraints.maxWidth >= 700 && scale < 1.5
          ? 3
          : constraints.maxWidth >= 420
          ? 2
          : 1;
      final width =
          (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          for (final (metric, icon) in _items)
            SizedBox(
              width: width,
              child: AdminSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(minHeight: 40 * scale),
                      child: Row(
                        children: [
                          Icon(icon, size: 20, color: AppColors.textSecondary),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              metric.label,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (loading && snapshot == null)
                      Container(
                        height: 30,
                        width: 72,
                        decoration: const BoxDecoration(
                          color: AppColors.bgLight,
                          borderRadius: AppRadius.sm,
                        ),
                      )
                    else
                      Text(
                        formatAdminCount(snapshot?[metric]),
                        style: AppTextStyles.displayMedium,
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
