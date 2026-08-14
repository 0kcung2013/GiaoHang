import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../data/risk_intervention_repository.dart';

bool riskInterventionBlocksDelivery(RiskIntervention? intervention) {
  return intervention?.state == RiskInterventionState.returnRequired ||
      intervention?.state == RiskInterventionState.handoffRequired ||
      intervention?.state == RiskInterventionState.heldBeforePickup ||
      intervention?.state == RiskInterventionState.released;
}

class DriverRiskInstructionRegion extends StatelessWidget {
  const DriverRiskInstructionRegion({
    required this.orderId,
    required this.repository,
    required this.builder,
    super.key,
  });

  final String orderId;
  final RiskInterventionRepository repository;
  final Widget Function(BuildContext context, bool blocksDelivery) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RiskIntervention?>(
      stream: repository.watchForOrder(orderId),
      builder: (context, snapshot) {
        final intervention = snapshot.data;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (intervention != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: DriverRiskInstructionCard(
                  intervention: intervention,
                  onConfirmCustody: () => repository.confirmCustodyResolved(
                    intervention.riskReportId,
                  ),
                ),
              ),
            builder(context, riskInterventionBlocksDelivery(intervention)),
          ],
        );
      },
    );
  }
}

class DriverRiskInstructionCard extends StatefulWidget {
  const DriverRiskInstructionCard({
    required this.intervention,
    required this.onConfirmCustody,
    super.key,
  });

  final RiskIntervention intervention;
  final Future<void> Function() onConfirmCustody;

  @override
  State<DriverRiskInstructionCard> createState() =>
      _DriverRiskInstructionCardState();
}

class _DriverRiskInstructionCardState extends State<DriverRiskInstructionCard> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.intervention.state;
    final returnRequired = state == RiskInterventionState.returnRequired;
    final handoffRequired = state == RiskInterventionState.handoffRequired;
    final driverReleased =
        state == RiskInterventionState.heldBeforePickup ||
        state == RiskInterventionState.released;
    if (driverReleased) {
      return _card(
        icon: Icons.stop_circle_outlined,
        title: state == RiskInterventionState.heldBeforePickup
            ? 'Đơn đã được CSKH tạm giữ'
            : 'Chuyến giao đã kết thúc với bạn',
        body: 'Dừng thao tác giao hàng. Bạn có thể quay lại danh sách đơn.',
        urgent: true,
      );
    }
    if (!returnRequired && !handoffRequired) {
      if (state != RiskInterventionState.awaitingTriage) {
        return const SizedBox.shrink();
      }
      return _card(
        icon: Icons.support_agent_rounded,
        title: 'CSKH đang kiểm tra báo cáo',
        body: 'Bạn vẫn có thể tiếp tục giao hàng bình thường.',
        urgent: false,
      );
    }
    return _card(
      icon: returnRequired
          ? Icons.keyboard_return_rounded
          : Icons.handshake_outlined,
      title: returnRequired
          ? 'CSKH yêu cầu hoàn trả hàng'
          : 'CSKH yêu cầu bàn giao hàng',
      body:
          widget.intervention.instruction ?? 'Liên hệ CSKH để được hướng dẫn.',
      urgent: true,
      actionLabel: returnRequired
          ? 'Đã hoàn tất hoàn trả'
          : 'Đã hoàn tất bàn giao',
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String body,
    required bool urgent,
    String? actionLabel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: urgent ? AppColors.primary : AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(
          color: urgent ? AppColors.warning : AppColors.border,
          width: urgent ? 2 : 1,
        ),
        boxShadow: AppShadow.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.warning, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.headingSmall.copyWith(
                    color: urgent
                        ? AppColors.textOnDark
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: AppTextStyles.bodySmall.copyWith(
              color: urgent ? AppColors.textOnDark : AppColors.textSecondary,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            Material(
              color: AppColors.warning,
              borderRadius: AppRadius.md,
              child: InkWell(
                onTap: _submitting ? null : _confirm,
                borderRadius: AppRadius.md,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.center,
                  child: Text(
                    _submitting ? 'Đang xác nhận…' : actionLabel,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _DriverCustodyConfirmationDialog(state: widget.intervention.state),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      await widget.onConfirmCustody();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa thể xác nhận. Vui lòng kiểm tra mạng và thử lại.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _DriverCustodyConfirmationDialog extends StatelessWidget {
  const _DriverCustodyConfirmationDialog({required this.state});

  final RiskInterventionState state;

  @override
  Widget build(BuildContext context) {
    final returning = state == RiskInterventionState.returnRequired;
    final action = returning ? 'hoàn trả' : 'bàn giao';
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(AppSpacing.xl2),
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl,
          boxShadow: AppShadow.elevated,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.accent,
              size: 34,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Xác nhận đã $action hàng?',
              textAlign: TextAlign.center,
              style: AppTextStyles.headingMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Chỉ xác nhận khi người nhận đã tiếp nhận hàng. Thao tác này sẽ kết thúc trách nhiệm giữ hàng của bạn.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Chưa hoàn tất'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    key: const Key('confirm-driver-custody'),
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.accent,
                    ),
                    child: const Text('Xác nhận'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
