import 'package:flutter/material.dart';
import 'package:giaohang_config/giaohang_config.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/admin_surface.dart';
import 'controllers/business_settings_controller.dart';
import 'data/business_settings_repository.dart';
import 'settings_strings.dart';
import 'widgets/business_settings_form.dart';
import 'widgets/settings_history.dart';

class BusinessConfigurationScreen extends StatefulWidget {
  const BusinessConfigurationScreen({super.key, this.repository});
  final BusinessSettingsRepository? repository;
  @override
  State<BusinessConfigurationScreen> createState() =>
      BusinessConfigurationScreenState();
}

class BusinessConfigurationScreenState
    extends State<BusinessConfigurationScreen>
    with SingleTickerProviderStateMixin {
  late final BusinessSettingsController _controller;
  late final TabController _tabs;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _controller = BusinessSettingsController(
      widget.repository ??
          SupabaseBusinessSettingsRepository(Supabase.instance.client),
      updates: widget.repository == null
          ? BusinessSettingsLive(Supabase.instance.client).watch()
          : null,
    );
    _controller.load();
    _controller.loadHistory();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<bool> confirmLeave({String? message}) async {
    if (_controller.saving) return false;
    if (!_controller.dirty) return true;
    final discard =
        await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    SettingsStrings.unsaved,
                    style: AppTextStyles.headingSmall,
                  ),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Text(message),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(SettingsStrings.stay),
                      ),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(SettingsStrings.discard),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
    if (discard && mounted) _controller.useValues(_controller.current!.values);
    return discard;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.all(AppSpacing.xl2),
          child: AdminHeading(
            title: SettingsStrings.title,
            subtitle: SettingsStrings.subtitle,
          ),
        ),
        TabBar(
          controller: _tabs,
          labelStyle: AppTextStyles.labelLarge,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: SettingsStrings.editTab),
            Tab(text: SettingsStrings.historyTab),
          ],
        ),
        Expanded(
          child: _controller.current == null
              ? Center(
                  child: _controller.loading
                      ? const SizedBox(
                          width: 200,
                          child: LinearProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(SettingsStrings.loadError),
                            TextButton(
                              onPressed: _controller.load,
                              child: const Text(SettingsStrings.reload),
                            ),
                          ],
                        ),
                )
              : TabBarView(
                  controller: _tabs,
                  children: [
                    BusinessSettingsForm(
                      controller: _controller,
                      onReload: () async {
                        if (await confirmLeave(
                          message: SettingsStrings.reloadWarning,
                        )) {
                          await _controller.load();
                        }
                      },
                    ),
                    SettingsHistory(
                      controller: _controller,
                      onRestore: (revision) async {
                        if (await confirmLeave()) {
                          _controller.restore(revision);
                          _tabs.animateTo(0);
                        }
                      },
                    ),
                  ],
                ),
        ),
      ],
    ),
  );
}
