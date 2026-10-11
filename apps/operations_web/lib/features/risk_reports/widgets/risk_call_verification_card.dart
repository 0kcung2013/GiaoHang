import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../constants/risk_report_strings.dart';
import '../models/risk_report.dart';

enum _CallParty { recipient, customer }

enum _DemoOutcome {
  noAnswer(RiskReportStrings.noAnswer, Icons.phone_missed_rounded),
  busy(RiskReportStrings.lineBusy, Icons.phone_locked_rounded),
  answered(RiskReportStrings.answered, Icons.phone_in_talk_rounded);

  const _DemoOutcome(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Demo chỉ giữ kết quả trong UI, không tạo bằng chứng hay quyết định nghiệp vụ.
class RiskCallVerificationCard extends StatefulWidget {
  const RiskCallVerificationCard({
    required this.report,
    required this.enabled,
    super.key,
  });

  final RiskReport report;
  final bool enabled;

  @override
  State<RiskCallVerificationCard> createState() =>
      _RiskCallVerificationCardState();
}

class _RiskCallVerificationCardState extends State<RiskCallVerificationCard> {
  late _CallParty _party;
  _DemoOutcome _scenario = _DemoOutcome.noAnswer;
  _DemoOutcome? _result;
  Timer? _callTimer;
  bool _calling = false;
  bool _stopped = false;

  @override
  void initState() {
    super.initState();
    _party = _defaultParty;
  }

  RiskContact _contactFor(_CallParty party) {
    final order = widget.report.order;
    if (party == _CallParty.recipient) {
      return RiskContact(
        name: order.recipientName,
        phone: order.recipientPhone,
      );
    }
    return order.customer ??
        (widget.report.reporterRole == RiskReporterRole.customer
            ? RiskContact(
                name: widget.report.reporterName,
                phone: widget.report.reporterPhone,
              )
            : const RiskContact());
  }

  bool _hasPhone(_CallParty party) =>
      _contactFor(party).phone?.trim().isNotEmpty ?? false;

  _CallParty get _defaultParty =>
      _hasPhone(_CallParty.recipient) || !_hasPhone(_CallParty.customer)
      ? _CallParty.recipient
      : _CallParty.customer;

  @override
  void didUpdateWidget(covariant RiskCallVerificationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report.id != widget.report.id ||
        oldWidget.report.order.recipientPhone !=
            widget.report.order.recipientPhone ||
        oldWidget.report.order.customer?.phone !=
            widget.report.order.customer?.phone ||
        oldWidget.report.reporterPhone != widget.report.reporterPhone ||
        !widget.enabled) {
      _callTimer?.cancel();
      _party = _defaultParty;
      _calling = false;
      _stopped = false;
      _result = null;
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  void _call() {
    if (_calling) {
      _callTimer?.cancel();
      setState(() {
        _calling = false;
        _stopped = true;
      });
      return;
    }
    setState(() {
      _calling = true;
      _stopped = false;
      _result = null;
    });
    _callTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _calling = false;
        _result = _scenario;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final contact = _contactFor(_party);
    final name = contact.name?.trim();
    final phone = contact.phone?.trim();
    final canChooseParty =
        _hasPhone(_CallParty.recipient) && _hasPhone(_CallParty.customer);
    final resultColor = _result == _DemoOutcome.answered
        ? AppColors.primary
        : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  RiskReportStrings.callVerification,
                  style: AppTextStyles.headingSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.bgLight,
                  borderRadius: AppRadius.sm,
                ),
                child: Text(
                  RiskReportStrings.demo,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PopupMenuButton<_CallParty>(
            key: const Key('risk-call-contact'),
            tooltip: RiskReportStrings.contactCustomer,
            enabled: canChooseParty && !_calling && widget.enabled,
            initialValue: _party,
            color: AppColors.bgCard,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
            onSelected: (value) => setState(() {
              _party = value;
              _result = null;
              _stopped = false;
            }),
            itemBuilder: (_) => [
              for (final party in _CallParty.values)
                PopupMenuItem(
                  value: party,
                  child: Text(
                    _partyLabel(party),
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
            ],
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.bgLight,
                borderRadius: AppRadius.md,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _partyLabel(_party),
                          style: AppTextStyles.labelSmall,
                        ),
                        if (name != null && name.isNotEmpty)
                          Text(name, style: AppTextStyles.labelMedium),
                        Text(
                          phone == null || phone.isEmpty
                              ? RiskReportStrings.missingPhone
                              : phone,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canChooseParty)
                    const Icon(
                      Icons.unfold_more_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _calling
                      ? Icons.ring_volume_rounded
                      : _result?.icon ?? Icons.info_outline_rounded,
                  size: 18,
                  color: _calling ? AppColors.info : resultColor,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _calling
                        ? RiskReportStrings.ringing
                        : _stopped
                        ? RiskReportStrings.callStopped
                        : _result != null
                        ? '${RiskReportStrings.demo} · ${_result!.label}'
                        : RiskReportStrings.callDemoHint,
                    key: const Key('risk-call-status'),
                    style: AppTextStyles.bodySmall.copyWith(color: resultColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('risk-call-demo'),
                  onPressed: widget.enabled && _hasPhone(_party) ? _call : null,
                  icon: Icon(
                    _calling ? Icons.call_end_rounded : Icons.call_rounded,
                    size: 20,
                  ),
                  label: Text(
                    _calling
                        ? RiskReportStrings.stopCall
                        : _result == null
                        ? RiskReportStrings.callDemo
                        : RiskReportStrings.callAgain,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.md,
                    ),
                    textStyle: AppTextStyles.labelMedium,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              PopupMenuButton<_DemoOutcome>(
                key: const Key('risk-call-scenario'),
                tooltip:
                    '${RiskReportStrings.demoScenario}: ${_scenario.label}',
                enabled: !_calling && widget.enabled,
                initialValue: _scenario,
                color: AppColors.bgCard,
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
                onSelected: (value) => setState(() {
                  _scenario = value;
                  _result = null;
                  _stopped = false;
                }),
                itemBuilder: (_) => [
                  for (final outcome in _DemoOutcome.values)
                    CheckedPopupMenuItem(
                      value: outcome,
                      checked: outcome == _scenario,
                      child: Text(
                        outcome.label,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                ],
                icon: const Icon(
                  Icons.tune_rounded,
                  color: AppColors.textSecondary,
                ),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _partyLabel(_CallParty party) => switch (party) {
  _CallParty.recipient => RiskReportStrings.recipient,
  _CallParty.customer => RiskReportStrings.orderingCustomer,
};
