import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/risk_report.dart';
import '../utils/risk_report_ui.dart';

class RiskNoteHistory extends StatelessWidget {
  const RiskNoteHistory({required this.notes, super.key});

  final List<RiskReportNote> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return Text(
        'Chưa có ghi chú nội bộ.',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
      );
    }
    return Column(
      children: notes
          .map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: AppRadius.md,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.body,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${note.authorName ?? 'Nhân viên CSKH'} • '
                      '${RiskReportUi.formatDateTime(note.createdAt)}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
