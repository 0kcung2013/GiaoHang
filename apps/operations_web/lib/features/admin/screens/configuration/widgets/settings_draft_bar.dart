import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../controllers/business_settings_controller.dart';
import '../settings_strings.dart';

class SettingsDraftBar extends StatelessWidget {
  const SettingsDraftBar({
    super.key,
    required this.controller,
    required this.reviewing,
    required this.onReview,
  });
  final BusinessSettingsController controller;
  final bool reviewing;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final enabled =
        controller.dirty && !controller.saving && !controller.loading;
    final action = FilledButton.icon(
      key: const ValueKey('settings-primary-action'),
      onPressed: enabled && (!reviewing || controller.newer == null)
          ? reviewing
                ? () => controller.save()
                : onReview
          : null,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnDark,
        textStyle: AppTextStyles.labelMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        minimumSize: const Size(160, 48),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
      icon: Icon(
        reviewing ? Icons.save_outlined : Icons.fact_check_outlined,
        size: 20,
      ),
      label: Text(
        controller.saving
            ? SettingsStrings.saving
            : reviewing
            ? SettingsStrings.save
            : SettingsStrings.reviewTitle,
      ),
    );
    final summary = Semantics(
      liveRegion: true,
      child: Text(
        controller.dirty
            ? SettingsStrings.pendingChanges(controller.changedFields.length)
            : SettingsStrings.noChanges,
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl2,
        vertical: AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 500 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  summary,
                  const SizedBox(height: AppSpacing.sm),
                  action,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: summary),
                const SizedBox(width: AppSpacing.lg),
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}
