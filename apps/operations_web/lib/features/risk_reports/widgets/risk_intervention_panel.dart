import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart'
    show OrderReturn, ReturnApprovalDraft;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../returns/data/support_order_return_repository.dart';
import '../../returns/dialogs/support_return_approval_dialog.dart';
import '../../returns/services/return_route_quote_service.dart';
import '../../returns/widgets/support_return_progress.dart';
import '../dialogs/risk_operation_dialogs.dart';
import '../models/risk_report.dart';
import 'risk_internal_notes_section.dart';

typedef RiskDecisionCallback =
    Future<void> Function(RiskInterventionState decision, String? instruction);

class RiskInterventionPanel extends StatefulWidget {
  const RiskInterventionPanel({
    required this.report,
    required this.intervention,
    required this.orderStatus,
    required this.onHoldBeforePickup,
    required this.onDecision,
    this.onApproveReturn,
    required this.onConfirmCustody,
    required this.onResumeOrder,
    required this.onAddNote,
    this.notes = const [],
    this.canManage = true,
    this.canAddNote,
    this.managementBlockedMessage,
    super.key,
  });

  final RiskReport report;
  final RiskIntervention intervention;
  final String orderStatus;
  final Future<void> Function() onHoldBeforePickup;
  final RiskDecisionCallback onDecision;
  final Future<void> Function(ReturnApprovalDraft draft)? onApproveReturn;
  final Future<void> Function() onConfirmCustody;
  final Future<void> Function() onResumeOrder;
  final Future<void> Function(String body) onAddNote;
  final List<RiskReportNote> notes;
  final bool canManage;
  final bool? canAddNote;
  final String? managementBlockedMessage;

  @override
  State<RiskInterventionPanel> createState() => _RiskInterventionPanelState();
}

class _RiskInterventionPanelState extends State<RiskInterventionPanel> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Xác minh đơn hàng', style: AppTextStyles.headingSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Chọn hướng xử lý phù hợp',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ..._operationalActions(context),
          const SizedBox(height: AppSpacing.md),
          RiskInternalNotesSection(
            notes: widget.notes,
            canManage: widget.canAddNote ?? widget.canManage,
            onAddNote: widget.onAddNote,
          ),
        ],
      ),
    );
  }

  List<Widget> _operationalActions(BuildContext context) {
    final intervention = widget.intervention;
    if (!widget.canManage) {
      return [
        _InfoText(
          widget.managementBlockedMessage ??
              'Chỉ nhân viên đang phụ trách mới được can thiệp đơn.',
        ),
      ];
    }
    if (intervention.state == RiskInterventionState.awaitingTriage) {
      if (widget.orderStatus == 'assigned') {
        return [
          _PanelButton(
            label: 'Giữ đơn & giải phóng tài xế',
            icon: Icons.pause_circle_outline_rounded,
            onTap: _busy ? null : _confirmHoldBeforePickup,
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
                key: const Key('continue-delivery-button'),
                label: 'Tiếp tục giao',
                icon: Icons.play_arrow_rounded,
                onTap: _busy ? null : _confirmContinueDelivery,
              ),
              _PanelButton(
                key: const Key('return-order-button'),
                label: 'Hoàn hàng',
                icon: Icons.keyboard_return_rounded,
                secondary: true,
                onTap: _busy ? null : _requestReturn,
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
    if (intervention.state == RiskInterventionState.returnRequired) {
      return [
        StreamBuilder<OrderReturn?>(
          stream: SupportOrderReturnRepository(
            Supabase.instance.client,
          ).watchForOrder(widget.report.orderId),
          builder: (context, snapshot) => SupportReturnProgress(
            mission: snapshot.data,
            fallbackInstruction: intervention.instruction,
          ),
        ),
      ];
    }
    if (intervention.state == RiskInterventionState.handoffRequired) {
      return [
        _InfoText(intervention.instruction ?? 'Đang chờ xử lý hàng hóa.'),
        const SizedBox(height: AppSpacing.sm),
        _PanelButton(
          label: 'Xác nhận đã giải quyết hàng hóa',
          icon: Icons.task_alt_rounded,
          onTap: _busy ? null : _confirmCustodyResolved,
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
          onTap: _busy ? null : _confirmResumeOrder,
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

  Future<void> _requestReturn() async {
    final callback = widget.onApproveReturn;
    if (callback == null) {
      await _requestInstruction(RiskInterventionState.returnRequired);
      return;
    }
    final draft = await showSupportReturnApprovalDialog(
      context: context,
      report: widget.report,
      quoteService: ReturnRouteQuoteService(Supabase.instance.client),
    );
    if (draft == null || !mounted) return;
    await _run(() => callback(draft));
  }

  Future<void> _confirmHoldBeforePickup() async {
    final confirmed = await showRiskOperationConfirmationDialog(
      context,
      title: 'Tạm giữ đơn trước khi lấy hàng?',
      message:
          'Đơn sẽ rời hàng đợi của tài xế hiện tại và không thể tiếp tục giao cho đến khi CSKH cho phép phân công lại.',
      confirmLabel: 'Giữ đơn',
      icon: Icons.pause_circle_outline_rounded,
    );
    if (confirmed && mounted) await _run(widget.onHoldBeforePickup);
  }

  Future<void> _confirmContinueDelivery() async {
    final confirmed = await showRiskOperationConfirmationDialog(
      context,
      title: 'Cho phép tiếp tục giao?',
      message:
          'Tài xế sẽ tiếp tục quy trình giao hàng hiện tại. Quyết định được ghi vào lịch sử xử lý.',
      confirmLabel: 'Tiếp tục giao',
      icon: Icons.play_arrow_rounded,
    );
    if (!confirmed || !mounted) return;
    await _run(
      () => widget.onDecision(RiskInterventionState.continueDelivery, null),
    );
  }

  Future<void> _confirmCustodyResolved() async {
    final confirmed = await showRiskOperationConfirmationDialog(
      context,
      title: 'Xác nhận hàng hóa đã an toàn?',
      message:
          'Chỉ xác nhận sau khi tài xế hoàn tất hoàn trả hoặc bàn giao và đơn vị nhận đã tiếp nhận hàng.',
      confirmLabel: 'Đã giải quyết',
      icon: Icons.inventory_2_outlined,
    );
    if (confirmed && mounted) await _run(widget.onConfirmCustody);
  }

  Future<void> _confirmResumeOrder() async {
    final confirmed = await showRiskOperationConfirmationDialog(
      context,
      title: 'Cho phép phân công lại?',
      message:
          'Đơn sẽ quay lại luồng điều phối và có thể được giao cho một tài xế khác.',
      confirmLabel: 'Cho phép',
      icon: Icons.restart_alt_rounded,
    );
    if (confirmed && mounted) await _run(widget.onResumeOrder);
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
    super.key,
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

String _stateLabel(RiskInterventionState state) => switch (state) {
  RiskInterventionState.continueDelivery => 'Đã cho phép tài xế tiếp tục giao.',
  RiskInterventionState.heldBeforePickup => 'Đơn đã được tạm giữ.',
  RiskInterventionState.released => 'Tài xế đã được giải phóng.',
  _ => 'Đang xử lý quyết định vận hành.',
};
