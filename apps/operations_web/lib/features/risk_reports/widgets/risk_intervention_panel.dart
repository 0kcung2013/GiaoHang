import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../models/risk_report.dart';

typedef RiskDecisionCallback =
    Future<void> Function(RiskInterventionState decision, String? instruction);

class RiskInterventionPanel extends StatefulWidget {
  const RiskInterventionPanel({
    required this.report,
    required this.intervention,
    required this.orderStatus,
    required this.onHoldBeforePickup,
    required this.onDecision,
    required this.onConfirmCustody,
    required this.onResumeOrder,
    required this.onAddNote,
    super.key,
  });

  final RiskReport report;
  final RiskIntervention intervention;
  final String orderStatus;
  final Future<void> Function() onHoldBeforePickup;
  final RiskDecisionCallback onDecision;
  final Future<void> Function() onConfirmCustody;
  final Future<void> Function() onResumeOrder;
  final Future<void> Function(String body) onAddNote;

  @override
  State<RiskInterventionPanel> createState() => _RiskInterventionPanelState();
}

class _RiskInterventionPanelState extends State<RiskInterventionPanel> {
  final _noteController = TextEditingController();
  bool _busy = false;
  String? _noteError;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route_rounded, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text('Can thiệp vận hành', style: AppTextStyles.headingSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ..._operationalActions(context),
          const Divider(height: AppSpacing.xl3, color: AppColors.border),
          Text('Ghi chú nội bộ', style: AppTextStyles.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('risk-internal-note'),
            controller: _noteController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Thông tin chỉ CSKH và Admin nhìn thấy',
              errorText: _noteError,
              filled: true,
              fillColor: AppColors.bgCard,
              border: const OutlineInputBorder(borderRadius: AppRadius.md),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: _PanelButton(
              label: 'Lưu ghi chú',
              icon: Icons.note_add_outlined,
              onTap: _busy ? null : _addNote,
              secondary: true,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _operationalActions(BuildContext context) {
    final intervention = widget.intervention;
    if (widget.report.status == RiskStatus.open) {
      return [_InfoText('Tiếp nhận báo cáo trước khi can thiệp đơn.')];
    }
    if (intervention.state == RiskInterventionState.awaitingTriage) {
      if (widget.orderStatus == 'assigned') {
        return [
          _PanelButton(
            label: 'Giữ đơn & giải phóng tài xế',
            icon: Icons.pause_circle_outline_rounded,
            onTap: _busy ? null : () => _run(widget.onHoldBeforePickup),
          ),
        ];
      }
      if (widget.orderStatus == 'picking_up' ||
          widget.orderStatus == 'delivering') {
        return [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _PanelButton(
                label: 'Tiếp tục giao',
                icon: Icons.play_arrow_rounded,
                onTap: _busy
                    ? null
                    : () => _run(
                        () => widget.onDecision(
                          RiskInterventionState.continueDelivery,
                          null,
                        ),
                      ),
              ),
              _PanelButton(
                label: 'Yêu cầu hoàn trả',
                icon: Icons.keyboard_return_rounded,
                secondary: true,
                onTap: _busy
                    ? null
                    : () => _requestInstruction(
                        RiskInterventionState.returnRequired,
                      ),
              ),
              _PanelButton(
                label: 'Yêu cầu bàn giao',
                icon: Icons.handshake_outlined,
                secondary: true,
                onTap: _busy
                    ? null
                    : () => _requestInstruction(
                        RiskInterventionState.handoffRequired,
                      ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const _InfoText(
            'Tài xế vẫn bận đến khi hoàn trả hoặc bàn giao hàng xong.',
          ),
        ];
      }
      return [
        const _InfoText('Đơn tiếp tục bình thường khi chưa có lệnh giữ.'),
      ];
    }
    if (intervention.state == RiskInterventionState.returnRequired ||
        intervention.state == RiskInterventionState.handoffRequired) {
      return [
        _InfoText(intervention.instruction ?? 'Đang chờ xử lý hàng hóa.'),
        const SizedBox(height: AppSpacing.sm),
        _PanelButton(
          label: 'Xác nhận đã giải quyết hàng hóa',
          icon: Icons.task_alt_rounded,
          onTap: _busy ? null : () => _run(widget.onConfirmCustody),
        ),
      ];
    }
    if (widget.orderStatus == 'risk_hold') {
      return [
        const _InfoText('Đơn đang tạm giữ và tài xế cũ đã được giải phóng.'),
        const SizedBox(height: AppSpacing.sm),
        _PanelButton(
          label: 'Cho phép phân công lại',
          icon: Icons.restart_alt_rounded,
          onTap: _busy ? null : () => _run(widget.onResumeOrder),
        ),
      ];
    }
    return [_InfoText(_stateLabel(intervention.state))];
  }

  Future<void> _requestInstruction(RiskInterventionState decision) async {
    final instruction = await showRiskOperationInstructionDialog(
      context,
      decision,
    );
    if (instruction == null || !mounted) return;
    await _run(() => widget.onDecision(decision, instruction));
  }

  Future<void> _addNote() async {
    final body = _noteController.text.trim();
    if (body.length < 3) {
      setState(() => _noteError = 'Ghi chú cần ít nhất 3 ký tự.');
      return;
    }
    await _run(() => widget.onAddNote(body));
    if (mounted) {
      _noteController.clear();
      setState(() => _noteError = null);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.secondary = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: secondary ? AppColors.bgCard : AppColors.primary,
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.md,
            border: secondary ? Border.all(color: AppColors.border) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: secondary ? AppColors.primary : AppColors.textOnDark,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: secondary ? AppColors.primary : AppColors.textOnDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> showRiskOperationInstructionDialog(
  BuildContext context,
  RiskInterventionState decision,
) {
  return showDialog<String>(
    context: context,
    builder: (_) => _InstructionDialog(decision: decision),
  );
}

class _InstructionDialog extends StatefulWidget {
  const _InstructionDialog({required this.decision});
  final RiskInterventionState decision;

  @override
  State<_InstructionDialog> createState() => _InstructionDialogState();
}

class _InstructionDialogState extends State<_InstructionDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final returning = widget.decision == RiskInterventionState.returnRequired;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(AppSpacing.xl2),
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              returning ? 'Hướng dẫn hoàn trả' : 'Hướng dẫn bàn giao',
              style: AppTextStyles.headingMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('risk-operation-instruction'),
              controller: _controller,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Địa điểm, người nhận và lưu ý cho tài xế',
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
                    final value = _controller.text.trim();
                    if (value.length < 3) {
                      setState(() => _error = 'Vui lòng nhập hướng dẫn.');
                      return;
                    }
                    Navigator.pop(context, value);
                  },
                  child: const Text('Xác nhận'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _stateLabel(RiskInterventionState state) => switch (state) {
  RiskInterventionState.continueDelivery => 'Đã cho phép tài xế tiếp tục giao.',
  RiskInterventionState.heldBeforePickup => 'Đơn đã được tạm giữ.',
  RiskInterventionState.released => 'Tài xế đã được giải phóng.',
  _ => 'Đang xử lý quyết định vận hành.',
};
