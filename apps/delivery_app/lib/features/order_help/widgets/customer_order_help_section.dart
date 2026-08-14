import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../core/models/order_model.dart';
import '../../risk_reports/data/participant_risk_report_query_repository.dart';
import '../../risk_reports/models/participant_risk_report_summary.dart';
import '../data/customer_support_ticket_repository.dart';
import '../order_help_strings.dart';
import '../utils/order_help_ui.dart';
import 'customer_order_help_flow.dart';
import 'order_help_progress_sheet.dart';

class CustomerOrderHelpSection extends StatefulWidget {
  const CustomerOrderHelpSection({
    required this.order,
    this.compact = false,
    this.supportRepository,
    this.riskRepository,
    super.key,
  });

  final OrderModel order;
  final bool compact;
  final CustomerSupportTicketRepository? supportRepository;
  final ParticipantRiskReportQueryRepository? riskRepository;

  @override
  State<CustomerOrderHelpSection> createState() =>
      _CustomerOrderHelpSectionState();
}

class _CustomerOrderHelpSectionState extends State<CustomerOrderHelpSection> {
  late final CustomerSupportTicketRepository _supportRepository;
  late final ParticipantRiskReportQueryRepository _riskRepository;
  List<SupportTicket> _tickets = const [];
  List<ParticipantRiskReportSummary> _reports = const [];
  StreamSubscription<List<SupportTicket>>? _ticketSubscription;
  StreamSubscription<List<ParticipantRiskReportSummary>>? _reportSubscription;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _supportRepository =
        widget.supportRepository ?? SupabaseCustomerSupportTicketRepository();
    _riskRepository =
        widget.riskRepository ?? SupabaseParticipantRiskReportQueryRepository();
    _subscribeToUpdates();
    _load();
  }

  @override
  void dispose() {
    unawaited(_ticketSubscription?.cancel());
    unawaited(_reportSubscription?.cancel());
    super.dispose();
  }

  void _subscribeToUpdates() {
    _ticketSubscription = _supportRepository
        .watchForOrder(widget.order.id)
        .listen((tickets) {
          if (mounted) setState(() => _tickets = tickets);
        });
    _reportSubscription = _riskRepository.watchForOrder(widget.order.id).listen(
      (reports) {
        if (mounted) setState(() => _reports = reports);
      },
    );
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        _supportRepository.fetchForOrder(widget.order.id),
        _riskRepository.fetchForOrder(widget.order.id),
      ]);
      if (!mounted) return;
      setState(() {
        _tickets = results[0] as List<SupportTicket>;
        _reports = results[1] as List<ParticipantRiskReportSummary>;
      });
    } catch (_) {
      // Khu vực trợ giúp vẫn cho phép tạo yêu cầu khi lịch sử chưa tải được.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openFlow() async {
    final changed = await showCustomerOrderHelpFlow(
      context,
      order: widget.order,
      supportRepository: _supportRepository,
      riskQueryRepository: _riskRepository,
    );
    if (changed) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.order.status == 'pending' ||
        widget.order.status == 'cancelled') {
      return const SizedBox.shrink();
    }
    final records = <_HelpRecord>[
      ..._tickets.map(_HelpRecord.ticket),
      ..._reports.map(_HelpRecord.report),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final visibleRecords = records.take(widget.compact ? 1 : 3).toList();

    return Container(
      padding: EdgeInsets.all(widget.compact ? AppSpacing.md : AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: widget.compact ? null : AppShadow.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.bgWarm,
                  borderRadius: AppRadius.md,
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      OrderHelpStrings.entryLabel,
                      style: AppTextStyles.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      OrderHelpStrings.entryHint,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filled(
                key: const Key('open-order-help'),
                onPressed: _openFlow,
                tooltip: OrderHelpStrings.entryLabel,
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textOnAccent,
                ),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          if (_loading) ...[
            const SizedBox(height: AppSpacing.md),
            const LinearProgressIndicator(
              minHeight: 3,
              color: AppColors.accent,
              backgroundColor: AppColors.accentLight,
            ),
          ],
          if (visibleRecords.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.sm),
            for (final record in visibleRecords) ...[
              _HelpRecordTile(record: record, onTap: () => _openRecord(record)),
              if (record != visibleRecords.last)
                const SizedBox(height: AppSpacing.xs),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _openRecord(_HelpRecord record) {
    final ticket = record.ticket;
    if (ticket != null) {
      return showSupportTicketProgressSheet(
        context,
        ticket,
        _supportRepository,
      );
    }
    return showRiskReportProgressSheet(
      context,
      record.report!,
      _riskRepository,
    );
  }
}

class _HelpRecord {
  const _HelpRecord.ticket(this.ticket) : report = null;
  const _HelpRecord.report(this.report) : ticket = null;

  final SupportTicket? ticket;
  final ParticipantRiskReportSummary? report;

  DateTime get updatedAt => ticket?.updatedAt ?? report!.updatedAt;
  String get title => ticket?.subject ?? report!.title;
  String get shortId {
    final id = ticket?.id ?? report!.id;
    return id.length <= 8 ? id.toUpperCase() : id.substring(0, 8).toUpperCase();
  }

  String get statusLabel => ticket != null
      ? OrderHelpUi.supportStatusLabel(ticket!.status)
      : OrderHelpUi.riskStatusLabel(report!.status);
  Color get statusColor => ticket != null
      ? OrderHelpUi.supportStatusColor(ticket!.status)
      : OrderHelpUi.riskStatusColor(report!.status);
  IconData get statusIcon => ticket != null
      ? OrderHelpUi.supportStatusIcon(ticket!.status)
      : OrderHelpUi.riskStatusIcon(report!.status);
}

class _HelpRecordTile extends StatelessWidget {
  const _HelpRecordTile({required this.record, required this.onTap});

  final _HelpRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgLight,
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(record.statusIcon, color: record.statusColor, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium,
                    ),
                    Text(
                      '#${record.shortId} · ${record.statusLabel}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: record.statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
