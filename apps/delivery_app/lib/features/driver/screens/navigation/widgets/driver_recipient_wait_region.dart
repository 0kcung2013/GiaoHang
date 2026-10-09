import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../order_help/widgets/order_help_progress_sheet.dart';
import '../../../../risk_reports/data/participant_risk_report_query_repository.dart';
import '../../../../risk_reports/data/risk_intervention_repository.dart';
import '../../../../risk_reports/models/participant_risk_report_summary.dart';
import '../data/driver_delivery_arrival_repository.dart';
import '../models/driver_delivery_arrival.dart';
import '../models/driver_recipient_wait.dart';
import '../utils/driver_recipient_wait_strings.dart';
import 'driver_recipient_wait_card.dart';
import 'driver_redelivery_fee_dialog.dart';

/// Đồng hồ từ giờ server hiện có. Không thay đổi quyền nhận đơn của backend.
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
  final Stopwatch _clock = Stopwatch();
  late final DriverDeliveryArrivalRepository _arrivalRepository;
  StreamSubscription<List<ParticipantRiskReportSummary>>? _reportsSubscription;
  StreamSubscription<RiskIntervention?>? _interventionSubscription;
  List<ParticipantRiskReportSummary> _reports = [];
  RiskIntervention? _intervention;
  DateTime? _serverNow;
  Timer? _timer;
  String? _reportId;
  String? _error;
  bool _expanded = true;
  bool _expired = false;
  bool _refreshing = false;
  bool _sending = false;
  bool _returnRequested = false;

  DriverRecipientWait? get _wait => DriverRecipientWait.select(
    orderId: widget.order.id,
    driverUserId: widget.order.driverId,
    orderStatus: widget.order.status,
    reports: _reports,
    intervention: _intervention,
  );

  Duration? get _remaining => _serverNow == null
      ? null
      : _wait?.remainingAt(_serverNow!.add(_clock.elapsed));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _arrivalRepository =
        widget.arrivalRepository ?? DriverDeliveryArrivalRepository();
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
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_wait == null || _serverNow == null) return;
      final expired = _remaining == Duration.zero;
      setState(() {
        if (expired && !_expired) _expanded = true;
        _expired = expired;
      });
    });
  }

  void _onDisconnected() {
    if (!mounted) return;
    setState(() {
      _serverNow = null;
      _error = DriverRecipientWaitStrings.clockError;
    });
  }

  void _updateWait() {
    final id = _wait?.report.id;
    if (id == _reportId) return;
    _reportId = id;
    _serverNow = null;
    _expired = false;
    _expanded = true;
    _returnRequested = false;
    _error = null;
    if (id != null) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (_refreshing || _wait == null) return;
    final id = _wait!.report.id;
    _refreshing = true;
    try {
      final results = await Future.wait<Object?>([
        _arrivalRepository.read(widget.order.id),
        widget.reports.fetchForOrder(widget.order.id),
        widget.interventions.fetchForOrder(widget.order.id),
      ]);
      if (!mounted || _reportId != id) return;
      final arrival = results[0] as DriverDeliveryArrival;
      setState(() {
        _reports = results[1] as List<ParticipantRiskReportSummary>;
        _intervention = results[2] as RiskIntervention?;
        _serverNow = arrival.serverNow;
        _clock
          ..reset()
          ..start();
        _error = null;
        _expired = _remaining == Duration.zero;
        if (_expired) _expanded = true;
      });
      final repository = widget.reports;
      if (repository is ParticipantRiskConversationRepository) {
        final messages =
            await (repository as ParticipantRiskConversationRepository)
                .fetchMessages(id);
        if (mounted && _reportId == id) {
          setState(
            () => _returnRequested = messages.any(
              (message) =>
                  message.senderId == widget.order.driverId &&
                  message.body == DriverRecipientWaitStrings.returnMessage,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted && _reportId == id) _onDisconnected();
    } finally {
      _refreshing = false;
      if (mounted) setState(() {});
      if (mounted && _reportId != id && _wait != null) unawaited(_refresh());
    }
  }

  Future<void> _requestReturn() async {
    if (_sending ||
        _refreshing ||
        _returnRequested ||
        _remaining != Duration.zero) {
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
      // Kiểm tra lại giờ và chỉ dẫn trước khi gửi tin nhắn xin phép.
      await _refresh();
      if (!mounted || _wait?.report.id != id || _remaining != Duration.zero) {
        return;
      }
      if (!_returnRequested) {
        await (repository as ParticipantRiskConversationRepository).postMessage(
          id,
          DriverRecipientWaitStrings.returnMessage,
        );
      }
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

  Future<void> _openReport() async {
    final report = _wait?.report;
    if (report != null) {
      await showRiskReportProgressSheet(context, report, widget.reports);
    }
  }

  Future<void> _recall() async {
    final id = _wait?.report.id;
    final openReport = await showDriverRedeliveryFeeDialog(
      context,
      deliveryAddress: widget.order.deliveryAddress,
    );
    if (mounted && openReport == true && _wait?.report.id == id) {
      await _openReport();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wait != null) {
      setState(() => _serverNow = null);
      unawaited(_refresh());
    } else if (state != AppLifecycleState.resumed) {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reportsSubscription?.cancel();
    _interventionSubscription?.cancel();
    _timer?.cancel();
    _clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
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
                      pickupAddress: widget.order.pickupAddress,
                      remaining: _remaining,
                      error: _error,
                      sending: _sending,
                      returnRequested: _returnRequested,
                      onRecall: () => unawaited(_recall()),
                      onRequestReturn:
                          widget.reports
                                  is ParticipantRiskConversationRepository &&
                              _serverNow != null &&
                              !_refreshing
                          ? () => unawaited(_requestReturn())
                          : null,
                      onOpenReport: () => unawaited(_openReport()),
                      onMinimize: () => setState(() => _expanded = false),
                      onRetry: () => unawaited(_refresh()),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ] else if (_wait != null)
        Positioned(
          top: 100,
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          child: SafeArea(
            bottom: false,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnDark,
                minimumSize: const Size(48, 48),
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
              ),
              onPressed: () => setState(() => _expanded = true),
              child: Text(
                _expired
                    ? DriverRecipientWaitStrings.expired
                    : '${DriverRecipientWaitStrings.waiting} · ${_remaining == null ? DriverRecipientWaitStrings.syncing : DriverRecipientWaitCard.formatRemaining(_remaining!)}',
              ),
            ),
          ),
        ),
    ],
  );
}
