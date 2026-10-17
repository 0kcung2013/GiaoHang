import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../core/models/order_model.dart';
import '../data/participant_risk_report_query_repository.dart';
import '../models/participant_risk_report_summary.dart';
import '../utils/risk_report_strings.dart';
import 'risk_chat_sheet.dart';

/// Chờ quyết định trước nhận hàng; luôn mở lại hội thoại của yêu cầu hiện có.
class DriverPendingIncidentRegion extends StatefulWidget {
  const DriverPendingIncidentRegion({
    required this.order,
    required this.builder,
    this.pickupConfirmed = false,
    this.intervention,
    this.repository,
    super.key,
  });

  final OrderModel order;
  final bool pickupConfirmed;
  final RiskIntervention? intervention;
  final ParticipantRiskReportQueryRepository? repository;
  final Widget Function(BuildContext context, bool blocked) builder;

  @override
  State<DriverPendingIncidentRegion> createState() => _PendingIncidentState();
}

class _PendingIncidentState extends State<DriverPendingIncidentRegion> {
  ParticipantRiskReportQueryRepository? _repository;
  Stream<List<ParticipantRiskReportSummary>>? _stream;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant DriverPendingIncidentRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id ||
        oldWidget.repository != widget.repository) {
      _subscribe();
    }
  }

  void _subscribe() {
    try {
      _repository =
          widget.repository ?? SupabaseParticipantRiskReportQueryRepository();
      _stream = _repository!.watchForOrder(widget.order.id);
    } on AssertionError {
      // Tests without an initialized Supabase client still exercise the original region.
      _stream = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final beforePickup =
        !widget.pickupConfirmed &&
        widget.order.actualPickedUpAt == null &&
        const ['assigned', 'picking_up'].contains(widget.order.status);
    if (!beforePickup || _stream == null) return widget.builder(context, false);
    return StreamBuilder<List<ParticipantRiskReportSummary>>(
      stream: _stream,
      builder: (context, snapshot) {
        ParticipantRiskReportSummary? pending;
        for (final report
            in snapshot.data ?? const <ParticipantRiskReportSummary>[]) {
          if (report.category == RiskCategory.cargoIssue &&
              !report.status.isClosed &&
              report.reporterRole == RiskReporterRole.driver &&
              report.reportedBy == widget.order.driverId &&
              (widget.intervention?.riskReportId != report.id ||
                  widget.intervention?.state ==
                      RiskInterventionState.awaitingTriage)) {
            pending = report;
            break;
          }
        }
        final active = pending;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active != null)
              Container(
                key: const Key('driver-incident-pending'),
                width: double.infinity,
                margin: const EdgeInsets.all(AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.bgWarm,
                  borderRadius: AppRadius.lg,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.support_agent_rounded,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            RiskReportStrings.incidentPending,
                            style: AppTextStyles.labelLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      RiskReportStrings.incidentPendingHint,
                      style: AppTextStyles.bodySmall,
                    ),
                    TextButton(
                      onPressed: () => showParticipantRiskChatSheet(
                        context,
                        report: active,
                        requesterId: widget.order.driverId!,
                        orderCode: widget.order.trackingCode,
                        repository: _repository!,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size(48, 48),
                        textStyle: AppTextStyles.labelMedium,
                      ),
                      child: const Text(RiskReportStrings.viewConversation),
                    ),
                  ],
                ),
              ),
            widget.builder(context, active != null),
          ],
        );
      },
    );
  }
}
