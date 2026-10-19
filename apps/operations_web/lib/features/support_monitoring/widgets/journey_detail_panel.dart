import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../../risk_reports/models/risk_journey.dart';
import '../../support_orders/models/support_order.dart';
import 'journey_status.dart';
import '../constants/journey_strings.dart';
import '../data/journey_archive_repository.dart';
import '../models/archived_journey_order.dart';
import 'journey_empty_state.dart';
import 'journey_events.dart';
import 'journey_playback.dart';

class JourneyDetailPanel extends StatefulWidget {
  const JourneyDetailPanel({
    required this.item,
    required this.repository,
    this.onInvalidate,
    this.tileProvider,
    super.key,
  });
  final ArchivedJourneyOrder item;
  final JourneyArchiveRepository repository;
  final VoidCallback? onInvalidate;
  final TileProvider? tileProvider;
  @override
  State<JourneyDetailPanel> createState() => _JourneyDetailPanelState();
}

class _JourneyDetailPanelState extends State<JourneyDetailPanel> {
  late Future<RiskJourney> _journey = widget.repository.fetchJourney(
    widget.item.order.id,
  );
  late Future<List<SupportOrderStatusLog>> _events = _loadEvents();
  String? _driverId;

  Future<List<SupportOrderStatusLog>> _loadEvents() {
    final future = widget.repository.fetchEvents(widget.item.order.id);
    // Events can fail while GPS is still loading. The expansion reports that
    // error independently once opened, without losing the map.
    future.ignore();
    return future;
  }

  void _reload() => setState(() {
    widget.onInvalidate?.call();
    _driverId = null;
    _journey = widget.repository.fetchJourney(widget.item.order.id);
    _events = _loadEvents();
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: AppRadius.lg,
      border: Border.all(color: AppColors.border),
    ),
    child: ClipRRect(
      borderRadius: AppRadius.lg,
      child: FutureBuilder<RiskJourney>(
        future: _journey,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.info),
            );
          }
          if (snapshot.hasError) {
            return JourneyEmptyState(
              title: JourneyStrings.mapError,
              onRetry: _reload,
            );
          }
          final all = snapshot.data!;
          if (all.points.isEmpty) {
            return JourneyEmptyState(
              title: JourneyStrings.noPoints,
              subtitle: all.unavailableChunks > 0
                  ? JourneyStrings.mapError
                  : JourneyStrings.noPointsHint,
              onRetry: _reload,
            );
          }
          final drivers = all.points.map((p) => p.driverId).toSet().toList();
          final visible = _driverId == null
              ? all
              : RiskJourney(
                  all.points.where((p) => p.driverId == _driverId),
                  unavailableChunks: all.unavailableChunks,
                );
          return LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              key: const Key('journey-detail-scroll'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.item.order.trackingCode,
                                style: AppTextStyles.headingMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: JourneyStrings.refresh,
                              onPressed: _reload,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                        JourneyStatus(status: widget.item.order.status),
                        const SizedBox(height: AppSpacing.lg),
                        Wrap(
                          spacing: AppSpacing.lg,
                          runSpacing: AppSpacing.sm,
                          children: [
                            Text(
                              JourneyStrings.sampleCount(all.points.length),
                              style: AppTextStyles.bodySmall,
                            ),
                            Text(
                              JourneyStrings.driverCount(drivers.length),
                              style: AppTextStyles.bodySmall,
                            ),
                            Text(
                              JourneyStrings.retained,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'driver-${widget.item.order.id}/${identityHashCode(all)}/$_driverId',
                          ),
                          initialValue: _driverId == null
                              ? '__all'
                              : _driverId!.isEmpty
                              ? '__unknown'
                              : _driverId,
                          isExpanded: true,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            labelText: JourneyStrings.driver,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: '__all',
                              child: Text(
                                JourneyStrings.allDrivers,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            for (final id in drivers)
                              DropdownMenuItem(
                                value: id.isEmpty ? '__unknown' : id,
                                child: Text(
                                  id.isEmpty
                                      ? JourneyStrings.unknownDriver
                                      : JourneyStrings.driverId(id),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                          ],
                          onChanged: (value) => setState(
                            () => _driverId = value == '__all'
                                ? null
                                : value == '__unknown'
                                ? ''
                                : value,
                          ),
                        ),
                      ],
                    ),
                  ),
                  JourneyPlayback(
                    key: ValueKey(
                      '${widget.item.order.id}/${_driverId ?? 'all'}/${identityHashCode(all)}',
                    ),
                    order: widget.item.order,
                    journey: visible,
                    tileProvider: widget.tileProvider,
                    mapHeight: (constraints.maxHeight * .52).clamp(280, 520),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  JourneyEvents(
                    future: _events,
                    onRetry: () => setState(() {
                      _events = widget.repository.fetchEvents(
                        widget.item.order.id,
                      );
                    }),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
