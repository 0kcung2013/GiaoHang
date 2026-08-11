import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/risk_report_strings.dart';
import '../data/risk_report_repository.dart';
import '../dialogs/create_risk_report_dialog.dart';
import '../dialogs/risk_report_detail_dialog.dart';
import '../models/risk_report.dart';
import '../widgets/risk_report_card.dart';
import '../widgets/risk_report_filters.dart';
import '../widgets/risk_report_header.dart';
import '../widgets/risk_report_states.dart';

class RiskReportsView extends StatefulWidget {
  const RiskReportsView({
    required this.isAdmin,
    this.repository,
    this.currentUserId,
    super.key,
  });

  final bool isAdmin;
  final RiskReportRepository? repository;
  final String? currentUserId;

  @override
  State<RiskReportsView> createState() => _RiskReportsViewState();
}

class _RiskReportsViewState extends State<RiskReportsView> {
  final _searchController = TextEditingController();
  late final RiskReportRepository _repository;
  late final String _currentUserId;
  List<RiskReport> _reports = const [];
  RiskSeverity? _severity;
  RiskStatus? _status;
  String _query = '';
  bool _loading = true;
  String? _error;

  List<RiskReport> get _filteredReports {
    final normalizedQuery = _query.trim().toLowerCase();
    final filtered = _reports.where((report) {
      if (_severity != null && report.severity != _severity) return false;
      if (_status != null && report.status != _status) return false;
      if (normalizedQuery.isEmpty) return true;
      return report.title.toLowerCase().contains(normalizedQuery) ||
          report.order.trackingCode.toLowerCase().contains(normalizedQuery);
    }).toList();
    filtered.sort((left, right) {
      if (left.triageOverdue != right.triageOverdue) {
        return left.triageOverdue ? -1 : 1;
      }
      return right.updatedAt.compareTo(left.updatedAt);
    });
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    if (widget.repository != null && widget.currentUserId != null) {
      _repository = widget.repository!;
      _currentUserId = widget.currentUserId!;
    } else {
      final client = Supabase.instance.client;
      _repository = widget.repository ?? SupabaseRiskReportRepository(client);
      _currentUserId =
          widget.currentUserId ?? client.auth.currentUser?.id ?? '';
    }
    _loadReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = await _repository.fetchReports();
      if (mounted) setState(() => _reports = reports);
    } catch (_) {
      if (mounted) setState(() => _error = RiskReportStrings.loadError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createReport() async {
    final draft = await showDialog<RiskReportDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateRiskReportDialog(),
    );
    if (draft == null || !mounted) return;

    try {
      await _repository.createReport(draft);
      await _loadReports();
      if (mounted) _showMessage('Đã ghi nhận báo cáo rủi ro.');
    } on RiskReportRepositoryException catch (error) {
      if (mounted) _showMessage(error.message, error: true);
    } catch (_) {
      if (mounted) _showMessage('Không thể tạo báo cáo.', error: true);
    }
  }

  Future<void> _openReport(RiskReport report) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => RiskReportDetailDialog(
        report: report,
        currentUserId: _currentUserId,
        isAdmin: widget.isAdmin,
        repository: _repository,
      ),
    );
    if (changed == true) await _loadReports();
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = math.max(
          20.0,
          (constraints.maxWidth - 1180) / 2,
        );
        final filtered = _filteredReports;
        return RefreshIndicator(
          onRefresh: _loadReports,
          child: CustomScrollView(
            key: const Key('risk-reports-scroll-view'),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  24,
                  horizontalPadding,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: RiskReportHeader(
                    reports: _reports,
                    onCreate: _createReport,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  20,
                  horizontalPadding,
                  16,
                ),
                sliver: SliverToBoxAdapter(
                  child: RiskReportFilters(
                    searchController: _searchController,
                    selectedSeverity: _severity,
                    selectedStatus: _status,
                    onSearchChanged: (value) => setState(() => _query = value),
                    onSeverityChanged: (value) =>
                        setState(() => _severity = value),
                    onStatusChanged: (value) => setState(() => _status = value),
                  ),
                ),
              ),
              if (_loading)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    24,
                  ),
                  sliver: const SliverToBoxAdapter(child: RiskReportLoading()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: RiskReportEmpty(
                    title: _error!,
                    subtitle: 'Kiểm tra kết nối và quyền truy cập.',
                    onRetry: _loadReports,
                  ),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: RiskReportEmpty(
                    title: _reports.isEmpty
                        ? RiskReportStrings.noReports
                        : RiskReportStrings.noResults,
                    subtitle: _reports.isEmpty
                        ? 'Tạo báo cáo đầu tiên khi phát hiện dấu hiệu bất thường.'
                        : 'Thử thay đổi từ khóa hoặc bộ lọc.',
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    28,
                  ),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => RiskReportCard(
                      report: filtered[index],
                      currentUserId: _currentUserId,
                      onTap: () => _openReport(filtered[index]),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
