import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

class OrderConfirmationAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const OrderConfirmationAppBar({
    super.key,
    required this.canEdit,
    required this.onEdit,
  });

  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: false,
      titleSpacing: 0,
      title: Text(
        'Xác nhận đơn',
        style: AppTextStyles.headingMedium.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
      backgroundColor: AppColors.bgLight,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      actions: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: const BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: AppRadius.full,
          ),
          child: Text(
            'Xác nhận',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        TextButton.icon(
          onPressed: canEdit ? onEdit : null,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Sửa'),
          style: TextButton.styleFrom(foregroundColor: AppColors.accent),
        ),
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }
}
