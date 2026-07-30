import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';

class CreateOrderAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CreateOrderAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: false,
      titleSpacing: AppSpacing.sm,
      leadingWidth: 60,
      leading: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        child: Material(
          color: AppColors.bgCard,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            customBorder: const CircleBorder(),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
              size: 21,
            ),
          ),
        ),
      ),
      title: Text(
        'Tạo đơn mới',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.headingMedium.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: AppSpacing.lg),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: const BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: AppRadius.full,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.edit_note_rounded,
                color: AppColors.accent,
                size: 17,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Thông tin',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
      backgroundColor: AppColors.bgLight,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    );
  }
}
