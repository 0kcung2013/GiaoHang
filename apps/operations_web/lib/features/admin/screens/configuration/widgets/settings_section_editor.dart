import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../widgets/admin_surface.dart';
import '../controllers/business_settings_controller.dart';
import '../models/settings_section.dart';
import 'business_setting_input.dart';
import 'pricing_simulator.dart';

class SettingsSectionEditor extends StatelessWidget {
  const SettingsSectionEditor({
    super.key,
    required this.section,
    required this.controller,
  });
  final SettingsSection section;
  final BusinessSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final group = section.group!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(group.label, style: AppTextStyles.headingMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          group.hint,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl2),
        AdminSurface(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth >= 700 &&
                  MediaQuery.textScalerOf(context).scale(1) <= 1.3;
              final width = columns
                  ? (constraints.maxWidth - AppSpacing.xl2) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: AppSpacing.xl2,
                runSpacing: AppSpacing.xl2,
                children: [
                  for (final field in group.fields)
                    SizedBox(
                      width: width,
                      child: BusinessSettingInput(
                        inputKey: ValueKey(
                          '${controller.formGeneration}-${field.key}',
                        ),
                        field: field,
                        value: controller.texts[field.key] ?? '',
                        enabled: !controller.saving && !controller.loading,
                        attempted: controller.attempted,
                        onChanged: (value) => controller.edit(field.key, value),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        if (section == SettingsSection.pricing) ...[
          const SizedBox(height: AppSpacing.lg),
          AdminSurface(
            child: PricingSimulator(
              key: const ValueKey('pricing-simulator'),
              settings: controller.draftPricing,
              enabled: !controller.saving,
            ),
          ),
        ],
      ],
    );
  }
}
