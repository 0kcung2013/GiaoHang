import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../constants/admin_strings.dart';
import '../models/admin_section.dart';
import '../models/admin_snapshot.dart';
import 'admin_surface.dart';

class AdminDecisionQueue extends StatelessWidget {
  const AdminDecisionQueue({
    super.key,
    required this.snapshot,
    required this.onNavigate,
    required this.onProfileChanges,
    required this.onDisabledAccounts,
  });
  final AdminSnapshot? snapshot;
  final ValueChanged<AdminSection> onNavigate;
  final VoidCallback onProfileChanges;
  final VoidCallback onDisabledAccounts;
  @override
  Widget build(BuildContext context) => AdminSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AdminStrings.decisions, style: AppTextStyles.headingMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          AdminStrings.decisionsHint,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth >= 850 &&
                    MediaQuery.textScalerOf(context).scale(1) < 1.3
                ? 3
                : constraints.maxWidth >= 500
                ? 2
                : 1;
            final width =
                (constraints.maxWidth - AppSpacing.md * (columns - 1)) /
                columns;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final item in [
                  (
                    AdminMetric.kyc,
                    Icons.badge_rounded,
                    () => onNavigate(AdminSection.drivers),
                  ),
                  (
                    AdminMetric.changes,
                    Icons.manage_accounts_rounded,
                    onProfileChanges,
                  ),
                  (
                    AdminMetric.disabledAccounts,
                    Icons.lock_rounded,
                    onDisabledAccounts,
                  ),
                ])
                  SizedBox(
                    width: width,
                    child: Material(
                      color: AppColors.bgLight,
                      borderRadius: AppRadius.md,
                      child: InkWell(
                        key: ValueKey('admin-decision-${item.$1.name}'),
                        onTap: item.$3,
                        borderRadius: AppRadius.md,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    item.$2,
                                    size: 20,
                                    color: AppColors.accent,
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.arrow_outward_rounded,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                snapshot?[item.$1]?.toString() ?? '—',
                                style: AppTextStyles.headingLarge,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                item.$1.label,
                                style: AppTextStyles.labelMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
