import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../controllers/business_settings_controller.dart';
import '../models/settings_section.dart';
import '../settings_strings.dart';
import 'settings_draft_bar.dart';
import 'settings_draft_review.dart';
import 'settings_section_editor.dart';
import 'settings_section_navigation.dart';

class BusinessSettingsForm extends StatefulWidget {
  const BusinessSettingsForm({
    super.key,
    required this.controller,
    required this.onReload,
  });
  final BusinessSettingsController controller;
  final VoidCallback onReload;

  @override
  State<BusinessSettingsForm> createState() => _BusinessSettingsFormState();
}

class _BusinessSettingsFormState extends State<BusinessSettingsForm>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  SettingsSection _section = SettingsSection.pricing;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _select(SettingsSection section) {
    if (widget.controller.saving || section == _section) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() => _section = section);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = widget.controller;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 960 &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.3;
        final content = ListView(
          key: const ValueKey('settings-content'),
          controller: _scroll,
          padding: const EdgeInsets.all(AppSpacing.xl2),
          children: [
            if (!wide) ...[
              SettingsSectionNavigation(
                selected: _section,
                controller: controller,
                onSelected: _select,
                compact: true,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            _ConfigurationStatus(
              controller: controller,
              onReload: widget.onReload,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_section == SettingsSection.review)
              SettingsDraftReview(
                key: ValueKey('review-${controller.formGeneration}'),
                controller: controller,
                onEditSection: _select,
              )
            else
              SettingsSectionEditor(
                key: ValueKey('${_section.name}-${controller.formGeneration}'),
                section: _section,
                controller: controller,
              ),
          ],
        );
        return Column(
          children: [
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 248,
                          decoration: const BoxDecoration(
                            color: AppColors.bgCard,
                            border: Border(
                              right: BorderSide(color: AppColors.border),
                            ),
                          ),
                          child: SettingsSectionNavigation(
                            selected: _section,
                            controller: controller,
                            onSelected: _select,
                          ),
                        ),
                        Expanded(child: content),
                      ],
                    )
                  : content,
            ),
            SettingsDraftBar(
              controller: controller,
              reviewing: _section == SettingsSection.review,
              onReview: () => _select(SettingsSection.review),
            ),
          ],
        );
      },
    );
  }
}

class _ConfigurationStatus extends StatelessWidget {
  const _ConfigurationStatus({
    required this.controller,
    required this.onReload,
  });
  final BusinessSettingsController controller;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (controller.newer != null)
        const _Notice(SettingsStrings.newerVersion, error: true),
      if (controller.syncError != null)
        _Notice(controller.syncError!, error: true),
      if (controller.error != null) _Notice(controller.error!, error: true),
      if (controller.message != null) _Notice(controller.message!),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: [
          Text(
            'Phiên bản ${controller.current!.revision}',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: AppTextStyles.labelMedium,
              minimumSize: const Size(48, 48),
            ),
            onPressed: controller.saving || controller.loading
                ? null
                : onReload,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(SettingsStrings.reload),
          ),
        ],
      ),
    ],
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.error = false});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Semantics(
      liveRegion: true,
      child: Text(
        text,
        style: AppTextStyles.bodyMedium.copyWith(
          color: error ? AppColors.error : AppColors.success,
        ),
      ),
    ),
  );
}
