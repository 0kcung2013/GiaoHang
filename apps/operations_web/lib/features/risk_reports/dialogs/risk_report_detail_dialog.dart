import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/risk_report_repository.dart';
import '../models/risk_report.dart';
import '../models/risk_report_policy.dart';
import '../utils/risk_report_ui.dart';
import '../widgets/risk_badge.dart';
import '../widgets/risk_report_actions.dart';
import '../widgets/risk_report_detail_content.dart';

class RiskReportDetailDialog extends StatefulWidget {
  const RiskReportDetailDialog({
    required this.report,
    required this.currentUserId,
    required this.isAdmin,
    required this.repository,
    super.key,
  });

  final RiskReport report;
  final String currentUserId;
  final bool isAdmin;
  final RiskReportRepository repository;

  @override
  State<RiskReportDetailDialog> createState() => _RiskReportDetailDialogState();
}

class _RiskReportDetailDialogState extends State<RiskReportDetailDialog> {
  List<RiskReportEvent>? _events;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await widget.repository.fetchEvents(widget.report.id);
      if (mounted) setState(() => _events = events);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được lịch sử xử lý.');
    }
  }

  Future<void> _assignToMe() async {
    setState(() => _submitting = true);
    try {
      await widget.repository.assignToMe(widget.report.id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể nhận báo cáo này.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _changeStatus(RiskStatus status) async {
    String? resolution;
    if (RiskReportPolicy.requiresResolution(status)) {
      resolution = await showRiskResolutionDialog(context, status);
      if (resolution == null || !mounted) return;
    }

    setState(() => _submitting = true);
    try {
      await widget.repository.changeStatus(
        widget.report.id,
        status,
        resolution: resolution,
      );
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể cập nhật trạng thái.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final transitions = RiskReportPolicy.allowedTransitions(
      status: report.status,
      severity: report.severity,
      isAdmin: widget.isAdmin,
    );
    final criticalRestricted =
        report.severity == RiskSeverity.critical && !widget.isAdmin;
    final screen = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 820,
          maxHeight: screen.height - AppSpacing.xl3,
        ),
        child: Material(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              RiskReportDetailHeader(
                report: report,
                onClose: () => Navigator.pop(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          RiskBadge(
                            label: RiskReportUi.severityLabel(report.severity),
                            color: RiskReportUi.severityColor(report.severity),
                            icon: RiskReportUi.severityIcon(report.severity),
                          ),
                          RiskBadge(
                            label: RiskReportUi.statusLabel(report.status),
                            color: RiskReportUi.statusColor(report.status),
                            icon: RiskReportUi.statusIcon(report.status),
                          ),
                          RiskBadge(
                            label: RiskReportUi.categoryLabel(report.category),
                            color: AppColors.primary,
                            icon: RiskReportUi.categoryIcon(report.category),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      RiskOrderRoute(report: report),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Dấu hiệu và bằng chứng',
                        style: AppTextStyles.labelMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        report.description,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if ((report.resolution ?? '').isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        RiskResolutionBlock(text: report.resolution!),
                      ],
                      if (criticalRestricted) ...[
                        const SizedBox(height: AppSpacing.xl),
                        const CriticalRiskNotice(),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          _error!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl2),
                      Row(
                        children: [
                          Text(
                            'Lịch sử xử lý',
                            style: AppTextStyles.headingSmall,
                          ),
                          const Spacer(),
                          Text(
                            '${_events?.length ?? 0} sự kiện',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      RiskEventTimeline(events: _events),
                    ],
                  ),
                ),
              ),
              RiskReportActionBar(
                assignedToMe: report.assignedTo == widget.currentUserId,
                submitting: _submitting,
                transitions: transitions,
                onAssign: _assignToMe,
                onTransition: _changeStatus,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
