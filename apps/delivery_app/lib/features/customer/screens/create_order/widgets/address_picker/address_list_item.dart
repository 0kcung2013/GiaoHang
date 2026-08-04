import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../../core/models/saved_address_model.dart';
import '../../address_picker_strings.dart';

class AddressListItem extends StatelessWidget {
  const AddressListItem({
    super.key,
    required this.icon,
    required this.title,
    required this.address,
    required this.onTap,
    this.detail,
    this.note,
    this.badge,
    this.trailing,
    this.accentColor = AppColors.accent,
  });

  final IconData icon;
  final String title;
  final String address;
  final String? detail;
  final String? note;
  final String? badge;
  final Widget? trailing;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title, $address',
      child: Material(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.xl,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadius.xl,
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadow.subtle,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: AppRadius.md,
                  ),
                  child: Icon(icon, color: accentColor, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: AppTextStyles.labelLarge.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: const BoxDecoration(
                                color: AppColors.accentLight,
                                borderRadius: AppRadius.full,
                              ),
                              child: Text(
                                badge!,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        address,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      if (detail?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          detail!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (note?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.notes_rounded,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                note!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String savedAddressLabel(SavedAddressModel address) {
  return switch (address.labelType) {
    SavedAddressLabelType.home => AddressPickerStrings.home,
    SavedAddressLabelType.work => AddressPickerStrings.work,
    SavedAddressLabelType.warehouse => AddressPickerStrings.warehouse,
    SavedAddressLabelType.other =>
      address.customLabel ?? AddressPickerStrings.other,
  };
}

IconData savedAddressIcon(SavedAddressLabelType type) => switch (type) {
  SavedAddressLabelType.home => Icons.home_rounded,
  SavedAddressLabelType.work => Icons.business_rounded,
  SavedAddressLabelType.warehouse => Icons.warehouse_rounded,
  SavedAddressLabelType.other => Icons.bookmark_rounded,
};
