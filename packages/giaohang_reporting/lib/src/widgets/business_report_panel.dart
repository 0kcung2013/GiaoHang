import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../business_report_strings.dart';
import '../data/business_report_repository.dart';
import '../export/business_report_export.dart';
import '../export/share_business_report.dart';
import 'report_period_toolbar.dart';
import 'report_surface.dart';
import 'business_report_content.dart';
import 'report_export_sheet.dart';

class BusinessReportPanel extends StatefulWidget {
  const BusinessReportPanel({
    super.key,
    required this.customerId,
    this.repository,
    this.today,
    this.staffView = false,
    this.showGuide = true,
  });
  final String customerId;
  final BusinessReportRepository? repository;
  final DateTime? today;
  final bool staffView, showGuide;
  @override
  State<BusinessReportPanel> createState() => _BusinessReportPanelState();
}

class _BusinessReportPanelState extends State<BusinessReportPanel> {
  late final _repository =
      widget.repository ??
      SupabaseBusinessReportRepository(Supabase.instance.client);
  late final _today = widget.today ?? VietnamTime.now();
  late DateTime _start = DateTime(_today.year, _today.month);
  late DateTime _end = DateTime(_today.year, _today.month + 1);
  BusinessReport? _report;
  String? _error;
  bool _loading = true, _exporting = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BusinessReportPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customerId != widget.customerId) _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
    });
    try {
      final report = await _repository.fetch(widget.customerId, _start, _end);
      if (mounted && generation == _generation)
        setState(() => _report = report);
    } catch (e) {
      if (mounted && generation == _generation)
        setState(
          () => _error = switch (e) {
            PostgrestException(message: 'BUSINESS_REPORT_TOO_LARGE') =>
              BusinessReportStrings.tooLarge,
            PostgrestException(code: 'PGRST202') =>
              BusinessReportStrings.unavailable,
            PostgrestException(code: '42501') =>
              BusinessReportStrings.forbidden,
            _ => BusinessReportStrings.error,
          },
        );
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  Future<void> _pick() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(_today.year + 1, 1, 1),
      initialDateRange: DateTimeRange(
        start: _start,
        end: _end.subtract(const Duration(days: 1)),
      ),
      helpText: BusinessReportStrings.period,
      cancelText: BusinessReportStrings.cancel,
      saveText: BusinessReportStrings.choose,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: AppColors.accent),
        ),
        child: child!,
      ),
    );
    if (!mounted || selected == null) return;
    final end = DateTime(
      selected.end.year,
      selected.end.month,
      selected.end.day + 1,
    );
    if (businessReportBoundary(
          end,
        ).difference(businessReportBoundary(selected.start)).inDays >
        366) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(BusinessReportStrings.maxRange)),
      );
      return;
    }
    _start = selected.start;
    _end = end;
    await _load();
  }

  void _shift(int delta) {
    _start = DateTime(_start.year, _start.month + delta);
    _end = DateTime(_start.year, _start.month + 1);
    _load();
  }

  Future<void> _chooseExport() async {
    final report = _report;
    if (report == null || _exporting || _loading) return;
    final format = await showReportExportSheet(context, report);
    // A refresh or account change while the sheet is open invalidates its snapshot.
    if (!mounted || format == null || !identical(report, _report)) return;
    await _export(format);
  }

  Future<void> _export(BusinessReportFormat format) async {
    final report = _report;
    if (report == null || _exporting) return;
    final box = context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _exporting = true);
    try {
      await shareBusinessReport(report, format, origin);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(BusinessReportStrings.exportError)),
        );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _exporting ? () async {} : _load,
    color: AppColors.accent,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        ReportPeriodToolbar(
          start: _start,
          end: _end,
          loading: _loading,
          exporting: _exporting,
          onPick: _pick,
          onPrevious: _exporting || !_start.isAfter(DateTime(2020))
              ? null
              : () => _shift(-1),
          onNext:
              _exporting ||
                  !_start.isBefore(DateTime(_today.year, _today.month))
              ? null
              : () => _shift(1),
          onRefresh: _load,
          showGuide: widget.showGuide,
        ),
        const SizedBox(height: AppSpacing.md),
        if (_loading)
          const LinearProgressIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.accentLight,
          )
        else if (_error != null)
          ReportSurface(
            child: Column(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 32,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _load,
                  child: const Text(BusinessReportStrings.retry),
                ),
              ],
            ),
          )
        else if (_report != null)
          BusinessReportContent(
            key: ValueKey(_report!.generatedAt),
            report: _report!,
            exporting: _exporting,
            onExport: _exporting ? null : _chooseExport,
            staffView: widget.staffView,
          ),
      ],
    ),
  );
}
