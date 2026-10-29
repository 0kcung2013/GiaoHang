import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../support_orders/utils/support_order_ui.dart';
import '../../constants/admin_strings.dart';
import '../../data/admin_repository.dart';
import '../../models/admin_section.dart';
import '../../models/admin_snapshot.dart';
import '../../widgets/admin_metrics.dart';
import '../../widgets/admin_decision_queue.dart';
import '../../widgets/admin_surface.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    this.repository,
    required this.onNavigate,
    required this.onProfileChanges,
    this.onDisabledAccounts,
  });
  final AdminRepository? repository;
  final ValueChanged<AdminSection> onNavigate;
  final VoidCallback onProfileChanges;
  final VoidCallback? onDisabledAccounts;
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final _repository =
      widget.repository ?? SupabaseAdminRepository(Supabase.instance.client);
  AdminSnapshot? _snapshot;
  bool _loading = true, _snapshotFailed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final version = ++_generation;
    setState(() => _loading = true);
    AdminSnapshot? snapshot;
    var snapshotFailed = false;
    try {
      snapshot = await _repository.fetchSnapshot();
    } catch (_) {
      snapshotFailed = true;
    }
    if (!mounted || version != _generation) return;
    setState(() {
      _loading = false;
      _snapshot = snapshot;
      _snapshotFailed = snapshotFailed;
    });
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      key: const PageStorageKey('admin-overview-scroll'),
      padding: const EdgeInsets.all(AppSpacing.xl2),
      children: [
        AdminHeading(
          title: AdminStrings.overview,
          subtitle: AdminStrings.overviewHint,
          action: OutlinedButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(AdminStrings.refresh),
          ),
        ),
        const SizedBox(height: AppSpacing.xl2),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: LinearProgressIndicator(color: AppColors.accent),
          ),
        if (_snapshotFailed || _snapshot?.hasErrors == true)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Text(
              AdminStrings.partialError,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        AdminDecisionQueue(
          snapshot: _snapshot,
          onNavigate: widget.onNavigate,
          onProfileChanges: widget.onProfileChanges,
          onDisabledAccounts:
              widget.onDisabledAccounts ??
              () => widget.onNavigate(AdminSection.accounts),
        ),
        const SizedBox(height: AppSpacing.xl2),
        const AdminHeading(
          title: AdminStrings.systemOverview,
          subtitle: AdminStrings.allTime,
        ),
        const SizedBox(height: AppSpacing.md),
        AdminMetrics(snapshot: _snapshot, loading: _loading),
        if (_snapshot != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            AdminStrings.updated(
              SupportOrderUi.formatDateTime(_snapshot!.updatedAt),
            ),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    ),
  );
}
