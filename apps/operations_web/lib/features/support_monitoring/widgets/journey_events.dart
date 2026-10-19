import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../../support_orders/models/support_order.dart';
import '../../support_orders/utils/support_order_ui.dart';
import '../constants/journey_strings.dart';

class JourneyEvents extends StatelessWidget {
  const JourneyEvents({required this.future, required this.onRetry, super.key});
  final Future<List<SupportOrderStatusLog>> future;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    shape: const Border(),
    collapsedShape: const Border(),
    leading: const Icon(Icons.timeline_rounded, color: AppColors.textSecondary),
    title: Text(JourneyStrings.events, style: AppTextStyles.headingSmall),
    childrenPadding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      0,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
    children: [
      FutureBuilder<List<SupportOrderStatusLog>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator(color: AppColors.info);
          }
          if (snapshot.hasError) {
            return Column(
              children: [
                Text(
                  JourneyStrings.eventsError,
                  style: AppTextStyles.bodySmall,
                ),
                TextButton(
                  onPressed: onRetry,
                  child: const Text(JourneyStrings.retry),
                ),
              ],
            );
          }
          final events = snapshot.data!;
          if (events.isEmpty) {
            return Text(
              JourneyStrings.eventsEmpty,
              style: AppTextStyles.bodySmall,
            );
          }
          return Column(
            children: [
              for (final event in events)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.xs),
                        child: Icon(
                          Icons.circle,
                          size: 8,
                          color: AppColors.info,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.displayTitle ??
                                  SupportOrderUi.statusLabel(event.status),
                              style: AppTextStyles.labelMedium,
                            ),
                            Text(
                              SupportOrderUi.formatDateTime(event.createdAt),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (event.displayDescription?.isNotEmpty == true)
                              Text(
                                event.displayDescription!,
                                style: AppTextStyles.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}
