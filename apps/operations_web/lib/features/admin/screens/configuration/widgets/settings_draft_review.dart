import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../widgets/admin_surface.dart';
import '../controllers/business_settings_controller.dart';
import '../models/settings_section.dart';
import '../settings_strings.dart';
import 'pricing_impact_comparison.dart';
import 'settings_changes.dart';

class SettingsDraftReview extends StatelessWidget {
  const SettingsDraftReview({
    super.key,
    required this.controller,
    required this.onEditSection,
  });
  final BusinessSettingsController controller;
  final ValueChanged<SettingsSection> onEditSection;

  @override
  Widget build(BuildContext context) {
    if (!controller.dirty) {
      return AdminSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.fact_check_outlined,
              size: 32,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(SettingsStrings.noChanges, style: AppTextStyles.headingMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(SettingsStrings.noChangesHint, style: AppTextStyles.bodySmall),
          ],
        ),
      );
    }
    final invalid = controller.invalidFields.toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(SettingsStrings.reviewTitle, style: AppTextStyles.headingMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(SettingsStrings.reviewHint, style: AppTextStyles.bodySmall),
        if (controller.attempted &&
            (invalid.isNotEmpty || controller.relationsError != null)) ...[
          const SizedBox(height: AppSpacing.lg),
          AdminSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  SettingsStrings.reviewValidation,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.error,
                  ),
                ),
                for (final section in SettingsSection.values.where(
                  (s) => s.group != null,
                ))
                  if (section.group!.fields.any(invalid.contains))
                    TextButton(
                      onPressed: () => onEditSection(section),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        textStyle: AppTextStyles.labelMedium,
                        minimumSize: const Size(48, 48),
                        alignment: Alignment.centerLeft,
                      ),
                      child: Text(
                        '${section.label}: ${section.group!.fields.where(invalid.contains).map((f) => f.label).join(', ')}',
                      ),
                    ),
                if (controller.relationsError != null)
                  Text(
                    controller.relationsError!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        for (final section in SettingsSection.values.where(
          (s) => s.group != null,
        ))
          if (controller.changesIn(section.group!) > 0) ...[
            AdminSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    children: [
                      Text(section.label, style: AppTextStyles.headingSmall),
                      TextButton.icon(
                        onPressed: controller.saving
                            ? null
                            : () => onEditSection(section),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text(SettingsStrings.editSection),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          textStyle: AppTextStyles.labelMedium,
                          minimumSize: const Size(48, 48),
                        ),
                      ),
                    ],
                  ),
                  SettingsChanges(
                    before: {
                      for (final f in section.group!.fields)
                        f.key: controller.current!.values[f.key],
                    },
                    after: {
                      for (final f in section.group!.fields)
                        f.key:
                            f.parse(controller.texts[f.key] ?? '') ??
                            controller.texts[f.key],
                    },
                    fields: section.group!.fields,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        if (controller.pricingChanged) ...[
          AdminSurface(
            child: PricingImpactComparison(
              before: controller.current!,
              after: controller.draftPricing!,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        AdminSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: ValueKey('reason-${controller.formGeneration}'),
                initialValue: controller.reason,
                enabled: !controller.saving,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                onChanged: (value) => controller.reason = value,
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  labelText: SettingsStrings.reason,
                  labelStyle: AppTextStyles.bodySmall,
                  floatingLabelStyle: AppTextStyles.labelMedium,
                  counterStyle: AppTextStyles.bodySmall,
                  errorMaxLines: 3,
                  errorText:
                      controller.attempted &&
                          (controller.reason.trim().length < 5 ||
                              controller.reason.trim().length > 500)
                      ? SettingsStrings.reasonError
                      : null,
                  border: const OutlineInputBorder(borderRadius: AppRadius.md),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                SettingsStrings.effectiveHint,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: controller.saving
                      ? null
                      : () => controller.useValues(controller.current!.values),
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text(SettingsStrings.discard),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: AppTextStyles.labelMedium,
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
