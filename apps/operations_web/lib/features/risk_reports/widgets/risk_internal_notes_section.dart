import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/risk_report.dart';
import 'risk_note_history.dart';

class RiskInternalNotesSection extends StatefulWidget {
  const RiskInternalNotesSection({
    required this.notes,
    required this.canManage,
    required this.onAddNote,
    super.key,
  });

  final List<RiskReportNote> notes;
  final bool canManage;
  final Future<void> Function(String body) onAddNote;

  @override
  State<RiskInternalNotesSection> createState() =>
      _RiskInternalNotesSectionState();
}

class _RiskInternalNotesSectionState extends State<RiskInternalNotesSection> {
  final _controller = TextEditingController();
  late bool _expanded;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _expanded = widget.notes.isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant RiskInternalNotesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notes.isEmpty && widget.notes.isNotEmpty) {
      _expanded = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.bgLight,
          borderRadius: AppRadius.md,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            mouseCursor: SystemMouseCursors.click,
            borderRadius: AppRadius.md,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadius.md,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.sticky_note_2_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Ghi chú nội bộ',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (widget.notes.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: AppSpacing.sm),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: AppRadius.full,
                      ),
                      child: Text(
                        '${widget.notes.length}',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: AppDuration.fast,
                    child: const Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: AppSpacing.md),
          RiskNoteHistory(notes: widget.notes),
          if (widget.canManage) ...[
            const SizedBox(height: AppSpacing.sm),
            LayoutBuilder(
              builder: (context, constraints) {
                final field = TextField(
                  key: const Key('risk-internal-note'),
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Thông tin chỉ CSKH và Admin nhìn thấy',
                    errorText: _error,
                    filled: true,
                    fillColor: AppColors.bgLight,
                    border: const OutlineInputBorder(
                      borderRadius: AppRadius.md,
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: AppRadius.md,
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: AppRadius.md,
                      borderSide: BorderSide(
                        color: AppColors.borderFocus,
                        width: 1.5,
                      ),
                    ),
                  ),
                );
                final save = OutlinedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.md,
                    ),
                  ),
                  icon: const Icon(Icons.note_add_outlined, size: 19),
                  label: Text(_saving ? 'Đang lưu...' : 'Lưu ghi chú'),
                );
                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      field,
                      const SizedBox(height: AppSpacing.sm),
                      Align(alignment: Alignment.centerRight, child: save),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: field),
                    const SizedBox(width: AppSpacing.sm),
                    save,
                  ],
                );
              },
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _save() async {
    final body = _controller.text.trim();
    if (body.length < 3) {
      setState(() => _error = 'Ghi chú cần ít nhất 3 ký tự.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onAddNote(body);
      if (mounted) _controller.clear();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
