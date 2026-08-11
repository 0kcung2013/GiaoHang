import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'driver_card_actions.dart';

void showAssignedDriverDetailSheet(
  BuildContext context,
  DriverModel driver, {
  required VoidCallback onChat,
}) {
  final name = (driver.fullName?.trim().isNotEmpty ?? false)
      ? driver.fullName!.trim()
      : 'Tài xế giao hàng';
  final phone = driver.phone?.trim();
  final plate = driver.licensePlate?.trim();
  final vehicle = driver.vehicleSummary;
  final hasPhone = phone != null && phone.isNotEmpty;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
      final maxHeight = MediaQuery.sizeOf(ctx).height * 0.85;

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xl + bottomInset,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: AppRadius.full,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _SheetAvatar(name: name, avatarUrl: driver.avatarUrl),
                const SizedBox(height: AppSpacing.md),
                Text(
                  name,
                  style: AppTextStyles.headingMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _SheetRatingChip(driver: driver),
                    if (driver.isVerified) const _SheetVerifiedBadge(),
                    if (driver.isNewDriver) const _SheetNewDriverBadge(),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                _SheetDetailRow(
                  label: 'Phương tiện',
                  value: vehicle.isEmpty ? '—' : vehicle,
                ),
                _SheetDetailRow(
                  label: 'Biển số',
                  value: (plate == null || plate.isEmpty) ? '—' : plate,
                ),
                _SheetDetailRow(
                  label: 'Số chuyến',
                  value: '${driver.totalDeliveries}',
                ),
                if (driver.ratingCount > 0)
                  _SheetDetailRow(
                    label: 'Lượt đánh giá',
                    value: '${driver.ratingCount}',
                  ),
                _SheetDetailRow(
                  label: 'Điện thoại',
                  value: hasPhone ? phone : '—',
                  isLast: true,
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: DriverContactActionButton(
                        icon: Icons.phone_rounded,
                        label: 'Gọi ngay',
                        filled: true,
                        enabled: hasPhone,
                        onTap: hasPhone
                            ? () => launchDriverTel(ctx, phone)
                            : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: DriverContactActionButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Chat',
                        filled: false,
                        enabled: true,
                        onTap: () {
                          Navigator.pop(ctx);
                          onChat();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SheetAvatar extends StatelessWidget {
  const _SheetAvatar({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final initials = _initials(name);
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accentLight,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  initials,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                initials,
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'TX';
    if (parts.length == 1) {
      final s = parts.first;
      return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
    }
    return ('${parts.first[0]}${parts.last[0]}').toUpperCase();
  }
}

class _SheetRatingChip extends StatelessWidget {
  const _SheetRatingChip({required this.driver});

  final DriverModel driver;

  @override
  Widget build(BuildContext context) {
    final hasScore = driver.rating != null;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: AppRadius.full,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasScore ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: 2),
          Text(
            driver.ratingLabel,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetVerifiedBadge extends StatelessWidget {
  const _SheetVerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: AppRadius.full,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_rounded,
            size: 14,
            color: AppColors.success,
          ),
          const SizedBox(width: 4),
          Text(
            'Đã xác minh',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetNewDriverBadge extends StatelessWidget {
  const _SheetNewDriverBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.12),
        borderRadius: AppRadius.full,
      ),
      child: Text(
        'Tài xế mới',
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.info,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SheetDetailRow extends StatelessWidget {
  const _SheetDetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
