import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../constants/risk_report_strings.dart';
import '../models/risk_report.dart';
import '../utils/risk_report_ui.dart';

class RiskReportActionBar extends StatelessWidget {
  const RiskReportActionBar({
    required this.assignedToMe,
    required this.unassigned,
    required this.submitting,
    required this.transitions,
    required this.onAssign,
    required this.onTransition,
    this.canTakeOver = false,
    this.onTakeOver,
    super.key,
  });

  final bool assignedToMe;
  final bool unassigned;
  final bool submitting;
  final List<RiskStatus> transitions;
  final VoidCallback onAssign;
  final ValueChanged<RiskStatus> onTransition;
  final bool canTakeOver;
  final VoidCallback? onTakeOver;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.bgLight,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (!assignedToMe && unassigned) ...[
              OutlinedButton.icon(
                onPressed: submitting ? null : onAssign,
                icon: const Icon(Icons.person_add_alt_rounded),
                label: const Text(RiskReportStrings.takeOwnership),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            if (!assignedToMe && !unassigned && canTakeOver) ...[
              OutlinedButton.icon(
                key: const Key('takeover-risk-report-button'),
                onPressed: submitting ? null : onTakeOver,
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('Admin tiếp quản'),
              ),
              const SizedBox(width: AppSpacing.sm),
            ] else if (!assignedToMe && !unassigned)
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.lock_person_outlined),
                label: const Text(RiskReportStrings.assignedToOther),
              ),
            for (
              var index = 0;
              assignedToMe && index < transitions.length;
              index++
            ) ...[
              if (index > 0) const SizedBox(width: AppSpacing.sm),
              index == 0
                  ? FilledButton.icon(
                      onPressed: submitting
                          ? null
                          : () => onTransition(transitions[index]),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      icon: Icon(RiskReportUi.statusIcon(transitions[index])),
                      label: Text(RiskReportUi.statusLabel(transitions[index])),
                    )
                  : OutlinedButton(
                      onPressed: submitting
                          ? null
                          : () => onTransition(transitions[index]),
                      child: Text(RiskReportUi.statusLabel(transitions[index])),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<String?> showRiskResolutionDialog(
  BuildContext context,
  RiskStatus status,
) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ResolutionDialog(status: status),
  );
}

class _ResolutionDialog extends StatefulWidget {
  const _ResolutionDialog({required this.status});
  final RiskStatus status;

  @override
  State<_ResolutionDialog> createState() => _ResolutionDialogState();
}

class _ResolutionDialogState extends State<_ResolutionDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Kết luận xử lý', style: AppTextStyles.headingMedium),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('risk-resolution-field'),
                controller: _controller,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: widget.status == RiskStatus.dismissed
                      ? 'Lý do xác định không có rủi ro'
                      : 'Biện pháp và kết quả xử lý',
                  errorText: _error,
                  filled: true,
                  fillColor: AppColors.bgLight,
                  border: const OutlineInputBorder(borderRadius: AppRadius.md),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: () {
                      if (_controller.text.trim().length < 3) {
                        setState(() => _error = 'Vui lòng nhập kết luận.');
                        return;
                      }
                      Navigator.pop(context, _controller.text.trim());
                    },
                    child: const Text('Xác nhận'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
