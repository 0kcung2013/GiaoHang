import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

class AdminDriverRegistryPanel extends StatelessWidget {
  const AdminDriverRegistryPanel({
    super.key,
    required this.drivers,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onOpenDriver,
  });

  final List<DriverModel> drivers;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<DriverModel> onOpenDriver;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.warning,
              size: 36,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              error!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(48, 48),
              ),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    if (drivers.isEmpty) {
      return Center(
        child: Text(
          'Không có tài xế nào',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      itemCount: drivers.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final driver = drivers[index];
        return _DriverRegistryCard(
          driver: driver,
          onTap: () => onOpenDriver(driver),
        );
      },
    );
  }
}

class _DriverRegistryCard extends StatelessWidget {
  const _DriverRegistryCard({required this.driver, required this.onTap});

  final DriverModel driver;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _DriverStatusVisual.from(driver.approvalStatus);
    final vehicleLine = [
      driver.vehicleType,
      driver.vehicleBrandModel,
      driver.vehicleColor,
    ].where((value) => value?.trim().isNotEmpty == true).join(' · ');

    return Material(
      color: AppColors.bgCard,
      borderRadius: AppRadius.lg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lg,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadow.subtle,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    backgroundImage: driver.avatarUrl?.trim().isNotEmpty == true
                        ? NetworkImage(driver.avatarUrl!)
                        : null,
                    child: driver.avatarUrl?.trim().isNotEmpty == true
                        ? null
                        : const Icon(
                            Icons.person_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.fullName ?? 'Chưa có tên',
                          style: AppTextStyles.headingSmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          driver.email ?? '',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.1),
                      borderRadius: AppRadius.full,
                      border: Border.all(
                        color: status.color.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      status.label,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: status.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _InfoRow(
                icon: Icons.phone_outlined,
                label: driver.phone ?? 'Chưa có SĐT',
              ),
              const SizedBox(height: AppSpacing.xs),
              _InfoRow(
                icon: Icons.directions_car_outlined,
                label: vehicleLine.isEmpty ? 'Chưa có xe' : vehicleLine,
              ),
              if (driver.licensePlate?.trim().isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.xs),
                _InfoRow(
                  icon: Icons.pin_outlined,
                  label: driver.licensePlate!.trim(),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Chạm để xem giấy tờ KYC và duyệt',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.info),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverStatusVisual {
  const _DriverStatusVisual(this.label, this.color);

  final String label;
  final Color color;

  factory _DriverStatusVisual.from(String status) => switch (status) {
    'pending' => const _DriverStatusVisual('Chờ duyệt', AppColors.warning),
    'approved' => const _DriverStatusVisual('Đã duyệt', AppColors.success),
    'rejected' => const _DriverStatusVisual('Từ chối', AppColors.error),
    _ => _DriverStatusVisual(status, AppColors.textMuted),
  };
}
