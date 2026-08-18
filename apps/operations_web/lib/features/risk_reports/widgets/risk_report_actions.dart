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
    this.statusLocked = false,
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
  final bool statusLocked;
  final bool canTakeOver;
  final VoidCallback? onTakeOver;

  @override
  Widget build(BuildContext context) {
    final primaryTransition = assignedToMe && transitions.isNotEmpty
        ? transitions.first
        : null;
    final secondaryTransitions = assignedToMe && transitions.length > 1
        ? transitions.skip(1).toList()
        : const <RiskStatus>[];

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl2,
        AppSpacing.md,
        AppSpacing.xl2,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppShadow.subtle,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final compactMenu = constraints.maxWidth < 440;
          final controls = Row(
            mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (!assignedToMe && unassigned)
                Flexible(
                  fit: compact ? FlexFit.tight : FlexFit.loose,
                  child: FilledButton.icon(
                    onPressed: submitting ? null : onAssign,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnDark,
                    ),
                    icon: const Icon(Icons.person_add_alt_rounded),
                    label: const Text(RiskReportStrings.takeOwnership),
                  ),
                )
              else if (!assignedToMe && !unassigned && canTakeOver)
                Flexible(
                  fit: compact ? FlexFit.tight : FlexFit.loose,
                  child: FilledButton.icon(
                    key: const Key('takeover-risk-report-button'),
                    onPressed: submitting ? null : onTakeOver,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnDark,
                    ),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('Admin tiếp quản'),
                  ),
                )
              else if (!assignedToMe && !unassigned)
                Flexible(
                  fit: compact ? FlexFit.tight : FlexFit.loose,
                  child: OutlinedButton.icon(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.lock_person_outlined),
                    label: const Text(RiskReportStrings.assignedToOther),
                  ),
                )
              else if (statusLocked)
                Flexible(
                  fit: compact ? FlexFit.tight : FlexFit.loose,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: AppRadius.md,
                      border: Border.all(color: AppColors.accent),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.lock_clock_outlined,
                          size: 20,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            RiskReportStrings.returnStatusLocked,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (primaryTransition != null) ...[
                Flexible(
                  fit: compact ? FlexFit.tight : FlexFit.loose,
                  child: FilledButton.icon(
                    onPressed: submitting
                        ? null
                        : () => onTransition(primaryTransition),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                      ),
                    ),
                    icon: Icon(RiskReportUi.statusIcon(primaryTransition)),
                    label: Text(RiskReportUi.statusLabel(primaryTransition)),
                  ),
                ),
                if (secondaryTransitions.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _MoreStatusMenu(
                    transitions: secondaryTransitions,
                    enabled: !submitting,
                    compact: compactMenu,
                    onSelected: onTransition,
                  ),
                ],
              ],
            ],
          );

          if (compact) return controls;
          return Row(
            children: [
              const Icon(
                Icons.change_circle_outlined,
                size: 20,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  assignedToMe
                      ? statusLocked
                            ? RiskReportStrings.returnStatusLocked
                            : 'Chọn bước xử lý tiếp theo'
                      : 'Quyền xử lý hồ sơ',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _MoreStatusMenu extends StatelessWidget {
  const _MoreStatusMenu({
    required this.transitions,
    required this.enabled,
    required this.compact,
    required this.onSelected,
  });

  final List<RiskStatus> transitions;
  final bool enabled;
  final bool compact;
  final ValueChanged<RiskStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<RiskStatus>(
      enabled: enabled,
      tooltip: 'Các trạng thái khác',
      onSelected: onSelected,
      itemBuilder: (context) => transitions
          .map(
            (status) => PopupMenuItem(
              value: status,
              height: 48,
              child: Row(
                children: [
                  Icon(
                    RiskReportUi.statusIcon(status),
                    size: 19,
                    color: RiskReportUi.statusColor(status),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      RiskReportUi.statusLabel(status),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.45,
        duration: AppDuration.fast,
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.more_horiz_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              if (!compact) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Trạng thái khác',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ],
          ),
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
