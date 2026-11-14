import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../business_report_strings.dart';
import '../utils/report_format.dart';
import 'report_reading_guide.dart';

class ReportPeriodToolbar extends StatelessWidget {
  const ReportPeriodToolbar({
    super.key,
    required this.start,
    required this.end,
    required this.loading,
    required this.exporting,
    required this.onPick,
    this.onPrevious,
    this.onNext,
    required this.onRefresh,
    this.showGuide = true,
  });
  final DateTime start, end;
  final bool loading, exporting, showGuide;
  final VoidCallback onPick, onRefresh;
  final VoidCallback? onPrevious, onNext;

  @override
  Widget build(BuildContext context) {
    final fullMonth =
        start.day == 1 && end == DateTime(start.year, start.month + 1);
    final period = Row(
      children: [
        IconButton(
          tooltip: BusinessReportStrings.previousMonth,
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.sm),
            ),
            onPressed: exporting ? null : onPick,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    fullMonth
                        ? BusinessReportStrings.month(start.month, start.year)
                        : '${reportDay(start)} – ${reportDay(end.subtract(const Duration(days: 1)))}',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelLarge,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.expand_more_rounded, size: 20),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: BusinessReportStrings.nextMonth,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showGuide)
          IconButton(
            tooltip: BusinessReportStrings.guide,
            onPressed: () => showReportReadingGuide(context),
            icon: const Icon(Icons.info_outline_rounded),
          ),
        IconButton(
          tooltip: BusinessReportStrings.refresh,
          onPressed: loading || exporting ? null : onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
    return IconButtonTheme(
      data: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.primary,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showGuide)
                  Align(alignment: Alignment.centerRight, child: actions),
                Row(
                  children: [
                    Expanded(child: period),
                    if (!showGuide) actions,
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              SizedBox(width: 360, child: period),
              const Spacer(),
              actions,
            ],
          );
        },
      ),
    );
  }
}
