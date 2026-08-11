import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../../../../order_contact/models/order_contact_message.dart';
import '../../../../order_contact/widgets/order_contact_chat_sheet.dart';
import 'assigned_driver_detail_sheet.dart';
import 'driver_card_actions.dart';

/// Card tài xế kiểu Grab/ShopeeFood trên màn tracking.
/// Dùng [assignedDriverProvider] (RPC public profile + fallback).
class AssignedDriverCard extends ConsumerWidget {
  const AssignedDriverCard({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverAsync = ref.watch(assignedDriverProvider(orderId));
    final cached = driverAsync.valueOrNull;

    if (cached != null) {
      return _DriverProfileCard(driver: cached, orderId: orderId);
    }

    return driverAsync.when(
      loading: () => const _DriverCardShell(child: _DriverCardSkeleton()),
      error: (_, _) => const _DriverCardShell(child: _DriverWaitingMessage()),
      data: (driver) {
        if (driver == null) {
          return const _DriverCardShell(child: _DriverWaitingMessage());
        }
        return _DriverProfileCard(driver: driver, orderId: orderId);
      },
    );
  }
}

class _DriverProfileCard extends StatelessWidget {
  const _DriverProfileCard({required this.driver, required this.orderId});

  final DriverModel driver;
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final name = (driver.fullName?.trim().isNotEmpty ?? false)
        ? driver.fullName!.trim()
        : 'Tài xế giao hàng';
    final plate = driver.licensePlate?.trim();
    final vehicleLine = driver.vehicleSummary;
    final phone = driver.phone?.trim();
    final hasPhone = phone != null && phone.isNotEmpty;
    Future<void> openChat() => showOrderContactChatSheet(
      context: context,
      orderId: orderId,
      currentUserId:
          Supabase.instance.client.auth.currentUser?.id ?? 'customer-demo',
      currentRole: OrderContactSenderRole.customer,
      counterpartName: name,
      stage: OrderContactStage.general,
    );

    return _DriverCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => showAssignedDriverDetailSheet(
              context,
              driver,
              onChat: openChat,
            ),
            borderRadius: AppRadius.md,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DriverAvatar(name: name, avatarUrl: driver.avatarUrl),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: AppTextStyles.headingSmall.copyWith(
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _RatingChip(driver: driver),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (vehicleLine.isNotEmpty)
                        Text(
                          vehicleLine,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (plate != null && plate.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          plate,
                          style: AppTextStyles.mono.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          if (driver.isVerified) const _VerifiedBadge(),
                          if (driver.isNewDriver) const _NewDriverBadge(),
                          _MetaChip(
                            icon: Icons.local_shipping_outlined,
                            label: '${driver.totalDeliveries} chuyến',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 22,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: DriverContactActionButton(
                  icon: Icons.phone_rounded,
                  label: 'Gọi',
                  filled: true,
                  enabled: hasPhone,
                  onTap: hasPhone
                      ? () => launchDriverTel(context, phone)
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DriverContactActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Nhắn tin',
                  filled: false,
                  enabled: true,
                  onTap: openChat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DriverCardShell extends StatelessWidget {
  const _DriverCardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: AppRadius.sm,
                ),
                child: const Icon(
                  Icons.delivery_dining_rounded,
                  color: AppColors.info,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Tài xế của bạn',
                style: AppTextStyles.headingSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  const _DriverAvatar({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final initials = _initials(name);

    return Container(
      width: 56,
      height: 56,
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
              errorBuilder: (_, _, _) => _InitialsAvatar(initials: initials),
            )
          : _InitialsAvatar(initials: initials),
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

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.driver});

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

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

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

class _NewDriverBadge extends StatelessWidget {
  const _NewDriverBadge();

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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.full,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverCardSkeleton extends StatelessWidget {
  const _DriverCardSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar({double w = 120, double h = 12}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.7),
        borderRadius: AppRadius.xs,
      ),
    );

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.border.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(w: 140, h: 14),
              const SizedBox(height: AppSpacing.sm),
              bar(w: 180),
              const SizedBox(height: AppSpacing.sm),
              bar(w: 90),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverWaitingMessage extends StatelessWidget {
  const _DriverWaitingMessage();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Tài xế đã nhận đơn. Đang tải thông tin…',
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textSecondary,
        height: 1.45,
      ),
    );
  }
}
