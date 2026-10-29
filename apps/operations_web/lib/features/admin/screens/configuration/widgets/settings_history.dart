import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../../../widgets/admin_surface.dart';
import '../controllers/business_settings_controller.dart';
import '../data/business_settings_repository.dart';
import '../settings_strings.dart';
import 'settings_changes.dart';
import '../models/settings_fields.dart';
import 'pricing_impact_comparison.dart';

class SettingsHistory extends StatelessWidget {
  const SettingsHistory({
    super.key,
    required this.controller,
    required this.onRestore,
  });
  final BusinessSettingsController controller;
  final ValueChanged<SettingsRevision> onRestore;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.xl2),
    children: [
      if (controller.historyError != null)
        Text(
          controller.historyError!,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
        ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: controller.historyLoading ? null : controller.loadHistory,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text(SettingsStrings.reload),
        ),
      ),
      if (controller.historyLoading)
        const LinearProgressIndicator(color: AppColors.primary),
      for (final revision in controller.history)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AdminSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Phiên bản ${revision.settings.revision} · ${revision.actor}',
                  style: AppTextStyles.labelLarge,
                ),
                Text(_formatTime(revision.at), style: AppTextStyles.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                SelectableText(
                  revision.reason,
                  style: AppTextStyles.bodyMedium,
                ),
                if (revision.previousValues != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  SettingsChanges(
                    before: revision.previousValues!,
                    after: revision.settings.values,
                  ),
                  if (pricingFieldKeys.any(
                        (key) =>
                            revision.previousValues![key] !=
                            revision.settings.values[key],
                      ) ||
                      revision.previousValues!.containsKey(
                            'long_distance_threshold_m',
                          ) !=
                          revision.settings.usesLegacyPricing)
                    ExpansionTile(
                      title: Text(
                        SettingsStrings.comparison,
                        style: AppTextStyles.labelMedium,
                      ),
                      childrenPadding: const EdgeInsets.only(
                        bottom: AppSpacing.md,
                      ),
                      children: [
                        PricingImpactComparison(
                          showHeading: false,
                          before: BusinessSettings(
                            values: revision.previousValues!,
                          ),
                          after: revision.settings,
                        ),
                      ],
                    ),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: controller.saving || controller.loading
                        ? null
                        : () => onRestore(revision),
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text(SettingsStrings.restore),
                  ),
                ),
              ],
            ),
          ),
        ),
      if (controller.moreHistory)
        OutlinedButton(
          onPressed: controller.historyLoading
              ? null
              : () => controller.loadHistory(more: true),
          child: const Text(SettingsStrings.more),
        ),
    ],
  );
}

String _formatTime(DateTime at) {
  final time = VietnamTime.toWallClock(at);
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${pad(time.day)}/${pad(time.month)}/${time.year} ${pad(time.hour)}:${pad(time.minute)}';
}
