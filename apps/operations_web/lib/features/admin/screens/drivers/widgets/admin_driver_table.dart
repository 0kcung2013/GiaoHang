import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../../../constants/admin_strings.dart';

class AdminDriverTable extends StatelessWidget {
  const AdminDriverTable({
    super.key,
    required this.drivers,
    required this.onOpen,
  });
  final List<DriverModel> drivers;
  final ValueChanged<DriverModel> onOpen;
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(AppSpacing.xl2),
    itemCount: drivers.length,
    separatorBuilder: (_, _) => const Divider(height: 1),
    itemBuilder: (context, index) {
      final driver = drivers[index];
      return Material(
        color: AppColors.bgCard,
        child: InkWell(
          onTap: () => onOpen(driver),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: AppRadius.md,
                  ),
                  child: const Icon(
                    Icons.two_wheeler_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.fullName ?? AdminStrings.missing,
                        style: AppTextStyles.labelLarge,
                      ),
                      Text(
                        driver.email ?? '',
                        style: AppTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.licensePlate ?? AdminStrings.missing,
                        style: AppTextStyles.mono,
                      ),
                      Text(
                        driver.vehicleBrandModel ??
                            driver.vehicleType ??
                            AdminStrings.missing,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    AdminStrings.approvalLabel(driver.approvalStatus),
                    style: AppTextStyles.labelMedium,
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        driver.ratingCount > 0
                            ? driver.rating?.toStringAsFixed(1) ?? '—'
                            : '—',
                        style: AppTextStyles.labelMedium,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(
                    AdminStrings.completedCount(driver.totalDeliveries),
                    style: AppTextStyles.bodySmall,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
