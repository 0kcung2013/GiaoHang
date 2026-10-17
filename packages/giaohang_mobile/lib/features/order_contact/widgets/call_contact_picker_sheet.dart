import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../order_contact_strings.dart';

class OrderCallContact {
  const OrderCallContact({
    required this.roleLabel,
    required this.name,
    required this.phone,
    required this.address,
  });

  final String roleLabel;
  final String name;
  final String phone;
  final String address;

  bool get canCall => phone.trim().isNotEmpty;
}

Future<OrderCallContact?> showCallContactPickerSheet({
  required BuildContext context,
  required OrderCallContact sender,
  required OrderCallContact recipient,
}) {
  return showModalBottomSheet<OrderCallContact>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl2,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: AppRadius.full,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: AppRadius.full,
              ),
              child: Text(
                OrderContactStrings.demoMode,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              OrderContactStrings.chooseCallTarget,
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              OrderContactStrings.chooseCallTargetHint,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _CallContactChoice(
              key: const Key('call-order-sender'),
              contact: sender,
              icon: Icons.storefront_rounded,
              color: AppColors.markerPickup,
              onTap: () => Navigator.pop(context, sender),
            ),
            const SizedBox(height: AppSpacing.md),
            _CallContactChoice(
              key: const Key('call-order-recipient'),
              contact: recipient,
              icon: Icons.person_pin_circle_rounded,
              color: AppColors.markerDrop,
              onTap: () => Navigator.pop(context, recipient),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CallContactChoice extends StatelessWidget {
  const _CallContactChoice({
    super.key,
    required this.contact,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final OrderCallContact contact;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = contact.canCall;
    final foreground = enabled ? color : AppColors.textMuted;
    return Semantics(
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      label: OrderContactStrings.callContactSemantic(
        roleLabel: contact.roleLabel,
        name: contact.name,
      ),
      child: Material(
        color: enabled ? color.withValues(alpha: 0.08) : AppColors.bgLight,
        borderRadius: AppRadius.lg,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: AppRadius.lg,
          child: Container(
            constraints: const BoxConstraints(minHeight: 88),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lg,
              border: Border.all(
                color: enabled
                    ? color.withValues(alpha: 0.28)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: foreground.withValues(alpha: 0.12),
                    borderRadius: AppRadius.md,
                  ),
                  child: Icon(icon, color: foreground, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.roleLabel,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        contact.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: enabled
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        enabled
                            ? contact.phone
                            : OrderContactStrings.phoneUnavailable,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        contact.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.call_rounded, color: foreground, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
