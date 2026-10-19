import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../risk_reports/constants/risk_journey_strings.dart';
import '../../risk_reports/data/risk_journey_repository.dart';
import '../../risk_reports/models/risk_journey.dart';
import '../../risk_reports/widgets/risk_journey_map.dart';
import '../constants/support_journey_strings.dart';
import '../data/support_order_context_repository.dart';
import '../models/support_monitoring_journey.dart';
import '../models/support_ticket.dart';

class SupportMonitoringJourneyDialog extends StatefulWidget {
  const SupportMonitoringJourneyDialog({
    required this.ticket,
    this.journeyRepository,
    this.orderRepository,
    this.tileProvider,
    super.key,
  });
  final SupportTicket ticket;
  final RiskJourneyRepository? journeyRepository;
  final SupportOrderContextRepository? orderRepository;
  final TileProvider? tileProvider;

  @override
  State<SupportMonitoringJourneyDialog> createState() =>
      _SupportMonitoringJourneyDialogState();
}

class _SupportMonitoringJourneyDialogState
    extends State<SupportMonitoringJourneyDialog> {
  late final scope = SupportMonitoringJourney(widget.ticket);
  late Future<(RiskJourney, SupportOrderContextData)> future = _load();

  Future<(RiskJourney, SupportOrderContextData)> _load() async {
    final orderId = widget.ticket.orderId!;
    final results = await (
      (widget.journeyRepository ?? RiskJourneyRepository()).fetch(orderId),
      (widget.orderRepository ??
              SupabaseSupportOrderContextRepository(Supabase.instance.client))
          .fetch(orderId),
    ).wait;
    return (scope.select(results.$1), results.$2);
  }

  void _reload() => setState(() {
    future = _load();
  });

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.bgCard,
    insetPadding: const EdgeInsets.all(AppSpacing.lg),
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
    child: SizedBox(
      width: 1100,
      height: MediaQuery.sizeOf(context).height * .9,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    SupportJourneyStrings.title,
                    style: AppTextStyles.headingMedium,
                  ),
                ),
                IconButton(
                  tooltip: RiskJourneyStrings.close,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Expanded(
              child: !scope.hasWindow
                  ? _message(SupportJourneyStrings.missingWindow)
                  : FutureBuilder<(RiskJourney, SupportOrderContextData)>(
                      future: future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accent,
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return _message(RiskJourneyStrings.loadError);
                        }
                        final (journey, contextData) = snapshot.data!;
                        if (journey.points.isEmpty) {
                          return _message(
                            journey.unavailableChunks > 0
                                ? RiskJourneyStrings.unreadable
                                : scope.end!.isBefore(
                                    DateTime.now().subtract(
                                      const Duration(days: 14),
                                    ),
                                  )
                                ? SupportJourneyStrings.expired
                                : SupportJourneyStrings.empty,
                          );
                        }
                        return LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '${widget.ticket.trackingCode ?? widget.ticket.orderId} · ${SupportJourneyStrings.window}',
                                  style: AppTextStyles.labelMedium,
                                ),
                                Text(
                                  '${RiskJourneyStrings.formatTime(scope.start!)} → ${RiskJourneyStrings.formatTime(scope.end!)}',
                                  style: AppTextStyles.bodySmall,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                SizedBox(
                                  height:
                                      (constraints.maxHeight - 100)
                                          .clamp(520, 900)
                                          .toDouble() *
                                      MediaQuery.textScalerOf(context).scale(1),
                                  child: RiskJourneyMap.forOrder(
                                    key: ObjectKey(journey),
                                    order: contextData.order,
                                    eventTime: scope.end!,
                                    journey: journey,
                                    tileProvider: widget.tileProvider,
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: _retryButton(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _retryButton() => TextButton.icon(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.info,
      minimumSize: const Size(48, 48),
      textStyle: AppTextStyles.labelMedium,
    ),
    onPressed: _reload,
    icon: const Icon(Icons.refresh_rounded),
    label: const Text(RiskJourneyStrings.reload),
  );

  Widget _message(String text) => Center(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.route_rounded,
            color: AppColors.textSecondary,
            size: 32,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium,
          ),
          if (scope.hasWindow) _retryButton(),
        ],
      ),
    ),
  );
}
