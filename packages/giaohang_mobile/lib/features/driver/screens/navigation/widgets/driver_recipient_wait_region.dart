import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../risk_reports/data/participant_risk_report_query_repository.dart';
import '../../../../risk_reports/data/risk_intervention_repository.dart';
import '../../../../risk_reports/models/participant_risk_report_summary.dart';
import '../../../../risk_reports/utils/risk_recipient_return_request.dart';
import '../../../../risk_reports/widgets/risk_chat_sheet.dart';
import '../data/driver_delivery_arrival_repository.dart';
import '../models/driver_recipient_wait.dart';
import '../utils/driver_delivery_arrival_strings.dart';
import '../utils/driver_recipient_wait_strings.dart';
import 'driver_recipient_wait_card.dart';
import 'driver_redelivery_fee_dialog.dart';
import '../../../../risk_reports/widgets/driver_report_status_scope.dart';

/// Chờ CSKH duyệt sau báo cáo. Không tự cấp quyền hoàn hoặc nhận đơn mới.
class DriverRecipientWaitRegion extends StatefulWidget {
  const DriverRecipientWaitRegion({
    super.key,
    required this.order,
    required this.reports,
    required this.interventions,
    required this.child,
    this.arrivalRepository,
  });

  final OrderModel order;
  final ParticipantRiskReportQueryRepository reports;
  final RiskInterventionRepository interventions;
  final DriverDeliveryArrivalRepository? arrivalRepository;
  final Widget child;

  @override
  State<DriverRecipientWaitRegion> createState() =>
      _DriverRecipientWaitRegionState();
}

class _DriverRecipientWaitRegionState extends State<DriverRecipientWaitRegion>
    with WidgetsBindingObserver {
  StreamSubscription<List<ParticipantRiskReportSummary>>? _reportsSubscription;
  StreamSubscription<RiskIntervention?>? _interventionSubscription;
  List<ParticipantRiskReportSummary> _reports = [];
  RiskIntervention? _intervention;
  String? _reportId;
  String? _error;
  bool _expanded = false;
  bool _synced = false;
  bool _refreshing = false;
  bool _sending = false;
  bool _returnRequested = false;
  bool _openingSupport = false;

  DriverRecipientWait? get _wait => DriverRecipientWait.select(
    orderId: widget.order.id,
    driverUserId: widget.order.driverId,
    orderStatus: widget.order.status,
    reports: _reports,
    intervention: _intervention,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reportsSubscription = widget.reports.watchForOrder(widget.order.id).listen(
      (reports) {
        setState(() => _reports = reports);
        _updateWait();
      },
      onError: (_) => _onDisconnected(),
    );
    _interventionSubscription = widget.interventions
        .watchForOrder(widget.order.id)
        .listen((intervention) {
          setState(() => _intervention = intervention);
          _updateWait();
        }, onError: (_) => _onDisconnected());
  }

  void _onDisconnected() {
    if (!mounted) return;
    setState(() {
      _synced = false;
      _error = DriverRecipientWaitStrings.syncError;
    });
  }

  void _updateWait() {
    final id = _wait?.report.id;
    if (id == _reportId) return;
    _reportId = id;
    _synced = false;
    _expanded = false;
    _returnRequested = _wait?.returnRequested ?? false;
    _error = null;
    if (id != null) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (_refreshing || _wait == null) return;
    final id = _wait!.report.id;
    _refreshing = true;
    _synced = false;
    try {
      final results = await Future.wait<Object?>([
        widget.reports.fetchForOrder(widget.order.id),
        widget.interventions.fetchForOrder(widget.order.id),
      ]);
      if (!mounted || _reportId != id) return;
      setState(() {
        _reports = results[0] as List<ParticipantRiskReportSummary>;
        _intervention = results[1] as RiskIntervention?;
        _returnRequested = _wait?.returnRequested ?? false;
        _error = null;
      });
      if (_wait?.report.id != id) {
        _updateWait();
        return;
      }
      final repository = widget.reports;
      if (!_returnRequested &&
          repository is ParticipantRiskConversationRepository) {
        final messages =
            await (repository as ParticipantRiskConversationRepository)
                .fetchMessages(id);
        if (mounted && _reportId == id) {
          setState(
            () => _returnRequested = messages.any(
              (message) =>
                  message.senderId == widget.order.driverId &&
                  RiskRecipientReturnRequest.isRequestMessage(message.body),
            ),
          );
        }
      }
      if (mounted && _reportId == id) setState(() => _synced = true);
    } catch (_) {
      if (mounted && _reportId == id) _onDisconnected();
    } finally {
      _refreshing = false;
      if (mounted) setState(() {});
      if (mounted && _reportId != id && _wait != null) unawaited(_refresh());
    }
  }

  Future<void> _requestReturn() async {
    if (_sending || _refreshing || _returnRequested || !_synced) {
      return;
    }
    final repository = widget.reports;
    if (repository is! ParticipantRiskConversationRepository) return;
    final wait = _wait;
    if (wait == null) return;
    final id = wait.report.id;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      // Báo cáo cũ chưa có yêu cầu hoàn: dùng lại case và kiểm tra quyền server.
      await _refresh();
      if (!mounted || _wait?.report.id != id || !_synced || _returnRequested) {
        return;
      }
      final arrival =
          await (widget.arrivalRepository ?? DriverDeliveryArrivalRepository())
              .read(widget.order.id);
      if (!mounted || _wait?.report.id != id) return;
      if (!arrival.canReport) {
        setState(() => _error = DriverDeliveryArrivalStrings.waitRequired);
        return;
      }
      await (repository as ParticipantRiskConversationRepository).postMessage(
        id,
        RiskRecipientReturnRequest.message,
      );
      if (mounted && _wait?.report.id == id) {
        setState(() => _returnRequested = true);
      }
    } catch (_) {
      if (mounted && _reportId == id) {
        setState(() => _error = DriverRecipientWaitStrings.sendError);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openSupport() async {
    if (_openingSupport || _wait == null) return;
    _openingSupport = true;
    try {
      await showParticipantRiskChatSheet(
        context,
        report: _wait!.report,
        requesterId: widget.order.driverId!,
        orderCode: widget.order.trackingCode,
        repository: widget.reports,
      );
    } finally {
      _openingSupport = false;
    }
  }

  Future<void> _recall() async {
    final id = _wait?.report.id;
    final contactSupport = await showDriverRedeliveryFeeDialog(
      context,
      deliveryAddress: widget.order.deliveryAddress,
    );
    if (mounted && contactSupport == true && _wait?.report.id == id) {
      await _openSupport();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wait != null) {
      setState(() => _synced = false);
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reportsSubscription?.cancel();
    _interventionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      DriverReportStatusScope(
        onOpen: _wait == null ? null : () => setState(() => _expanded = true),
        child: widget.child,
      ),
      if (_wait != null && _expanded) ...[
        ModalBarrier(
          color: AppColors.primary.withValues(alpha: 0.35),
          dismissible: false,
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - AppSpacing.xl3).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: DriverRecipientWaitCard(
                      orderCode: widget.order.trackingCode.isEmpty
                          ? widget.order.id
                          : widget.order.trackingCode,
                      error: _error,
                      sending: _sending,
                      returnRequested: _returnRequested,
                      onRecall: () => unawaited(_recall()),
                      onRequestReturn:
                          widget.reports
                                  is ParticipantRiskConversationRepository &&
                              _synced &&
                              !_refreshing
                          ? () => unawaited(_requestReturn())
                          : null,
                      onContactSupport: () => unawaited(_openSupport()),
                      onMinimize: () => setState(() => _expanded = false),
                      onRetry: () => unawaited(_refresh()),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}
