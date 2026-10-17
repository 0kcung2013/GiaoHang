import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../data/risk_journey_repository.dart';
import '../models/risk_journey.dart';
import '../models/risk_report.dart';
import '../widgets/risk_journey_map.dart';
import '../constants/risk_journey_strings.dart';

class RiskJourneyDialog extends StatefulWidget {
  const RiskJourneyDialog({required this.report, this.repository, super.key});
  final RiskReport report;
  final RiskJourneyRepository? repository;
  @override
  State<RiskJourneyDialog> createState() => _RiskJourneyDialogState();
}

class _RiskJourneyDialogState extends State<RiskJourneyDialog> {
  late final repository = widget.repository ?? RiskJourneyRepository();
  late Future<RiskJourney> future = repository.fetch(widget.report.orderId);
  void reload() =>
      setState(() => future = repository.fetch(widget.report.orderId));
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
                    RiskJourneyStrings.title,
                    style: AppTextStyles.headingMedium,
                  ),
                ),
                IconButton(
                  onPressed: reload,
                  tooltip: RiskJourneyStrings.reload,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: RiskJourneyStrings.close,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              RiskJourneyStrings.reportTime(widget.report.createdAt),
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: FutureBuilder<RiskJourney>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(RiskJourneyStrings.loadError),
                          TextButton(
                            onPressed: reload,
                            child: const Text(RiskJourneyStrings.retry),
                          ),
                        ],
                      ),
                    );
                  }
                  final journey = snapshot.data!;
                  if (journey.points.isEmpty) {
                    return Center(
                      child: Text(
                        journey.unavailableChunks > 0
                            ? RiskJourneyStrings.unreadable
                            : RiskJourneyStrings.empty,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return RiskJourneyMap(
                    key: ObjectKey(journey),
                    report: widget.report,
                    journey: journey,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
