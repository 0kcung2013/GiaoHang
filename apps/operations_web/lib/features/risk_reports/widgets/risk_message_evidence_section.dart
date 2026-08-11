import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/risk_message_evidence.dart';

abstract final class _Strings {
  static const title = 'Tin nhắn bằng chứng';
  static const attach = 'Gắn tin nhắn';
  static const sourceExpired = 'Tin nguồn đã hết hạn';
  static const emptyEvidence = 'Chưa gắn tin nhắn nào vào báo cáo.';
  static const emptyMessages = 'Đơn này chưa có tin nhắn để gắn.';
  static const close = 'Đóng';
}

class RiskMessageEvidenceSection extends StatelessWidget {
  const RiskMessageEvidenceSection({
    required this.evidence,
    required this.availableMessages,
    required this.loading,
    required this.attaching,
    required this.onAttach,
    super.key,
  });

  final List<RiskMessageEvidence> evidence;
  final List<RiskOrderMessage> availableMessages;
  final bool loading;
  final bool attaching;
  final Future<void> Function(List<String> messageIds) onAttach;

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (_) => _MessageEvidencePicker(messages: availableMessages),
    );
    if (selected != null && selected.isNotEmpty) await onAttach(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(_Strings.title, style: AppTextStyles.headingSmall),
            ),
            OutlinedButton.icon(
              onPressed: loading || attaching
                  ? null
                  : () => _openPicker(context),
              icon: const Icon(Icons.add_comment_rounded, size: 18),
              label: const Text(_Strings.attach),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.full),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (loading)
          const _EvidenceLoading()
        else if (evidence.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.bgLight,
              borderRadius: AppRadius.md,
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              _Strings.emptyEvidence,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          ...evidence.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _EvidenceCard(evidence: item),
            ),
          ),
      ],
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.evidence});

  final RiskMessageEvidence evidence;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.06),
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chat_rounded, color: AppColors.info, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(evidence.body, style: AppTextStyles.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Text(
                      _formatDate(evidence.sentAt),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (evidence.sourceMessageId == null)
                      Text(
                        _Strings.sourceExpired,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageEvidencePicker extends StatefulWidget {
  const _MessageEvidencePicker({required this.messages});

  final List<RiskOrderMessage> messages;

  @override
  State<_MessageEvidencePicker> createState() => _MessageEvidencePickerState();
}

class _MessageEvidencePickerState extends State<_MessageEvidencePicker> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: size.height * 0.8,
        ),
        child: Material(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl,
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    const Icon(Icons.fact_check_rounded, color: AppColors.info),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        _Strings.title,
                        style: AppTextStyles.headingMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: _Strings.close,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Flexible(
                child: widget.messages.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl2),
                        child: Text(
                          _Strings.emptyMessages,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: widget.messages.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final message = widget.messages[index];
                          final checked = _selected.contains(message.id);
                          return Material(
                            color: checked
                                ? AppColors.info.withValues(alpha: 0.08)
                                : AppColors.bgLight,
                            borderRadius: AppRadius.md,
                            child: InkWell(
                              borderRadius: AppRadius.md,
                              onTap: () => _toggle(message.id),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: checked,
                                      onChanged: (_) => _toggle(message.id),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            message.body,
                                            style: AppTextStyles.bodyMedium,
                                          ),
                                          Text(
                                            _formatDate(message.sentAt),
                                            style: AppTextStyles.labelSmall
                                                .copyWith(
                                                  color: AppColors.textMuted,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selected.toList()),
                    icon: const Icon(Icons.link_rounded),
                    label: Text('Gắn ${_selected.length} tin nhắn'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.full,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggle(String messageId) {
    setState(() {
      if (!_selected.add(messageId)) _selected.remove(messageId);
    });
  }
}

class _EvidenceLoading extends StatelessWidget {
  const _EvidenceLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.md,
      ),
    );
  }
}

String _formatDate(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)} · '
      '${two(value.day)}/${two(value.month)}/${value.year}';
}
