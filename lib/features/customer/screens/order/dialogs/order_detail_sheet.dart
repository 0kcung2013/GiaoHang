import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../../../../reviews/widgets/order_review_section.dart';
import '../../../widgets/delivery_proof/customer_delivery_proof_section.dart';
import '../../tracking/widgets/assigned_driver_card.dart';
import '../order_helpers.dart';
import 'order_detail_strings.dart';
import 'widgets/order_cancel_section.dart';
import 'widgets/order_detail_activity.dart';
import 'widgets/order_detail_header.dart';
import 'widgets/order_detail_information.dart';

const orderDetailSheetKey = Key('order-detail-sheet');

void showOrderDetailSheet({
  required BuildContext context,
  required String customerId,
  required OrderModel order,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => OrderDetailSheet(customerId: customerId, order: order),
  );
}

class OrderDetailSheet extends ConsumerStatefulWidget {
  const OrderDetailSheet({
    super.key,
    required this.customerId,
    required this.order,
  });

  final String customerId;
  final OrderModel order;

  @override
  ConsumerState<OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends ConsumerState<OrderDetailSheet> {
  static const _cancellableStatuses = {
    'pending',
    'confirmed',
    'assigned',
    'picking_up',
  };
  static const _warnBeforeCancelStatuses = {'assigned', 'picking_up'};

  final _reasonController = TextEditingController();
  bool _showReasonInput = false;
  bool _isCancelling = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final canCancel = _cancellableStatuses.contains(order.status);
    final note = order.note?.trim();

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.58,
      maxChildSize: 0.97,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          key: orderDetailSheetKey,
          decoration: const BoxDecoration(
            color: AppColors.bgLight,
            borderRadius: AppRadius.xl2,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.md,
                  AppSpacing.screenH,
                  AppSpacing.xl2 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: AppSpacing.md),
                  OrderDetailSheetHeader(
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  OrderDetailSummaryCard(
                    order: order,
                    status: OrderStatusView.fromStatus(order.status),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OrderDetailCargoCard(order: order),
                  const SizedBox(height: AppSpacing.md),
                  OrderDetailRouteCard(order: order),
                  const SizedBox(height: AppSpacing.md),
                  OrderDetailPaymentCard(order: order),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    OrderDetailNoteCard(note: note),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  OrderDetailItemsSection(orderId: order.id),
                  const SizedBox(height: AppSpacing.md),
                  OrderDetailTimelineSection(order: order),
                  if (const {
                    'picking_up',
                    'delivering',
                    'delivered',
                  }.contains(order.status)) ...[
                    const SizedBox(height: AppSpacing.md),
                    CustomerDeliveryProofSection(
                      orderId: order.id,
                      orderStatus: order.status,
                    ),
                  ],
                  if (shouldShowAssignedDriverForOrder(order)) ...[
                    const SizedBox(height: AppSpacing.md),
                    AssignedDriverCard(orderId: order.id),
                  ],
                  if (order.status == 'delivered') ...[
                    const SizedBox(height: AppSpacing.md),
                    OrderReviewSection(order: order),
                  ],
                  if (canCancel) ...[
                    const SizedBox(height: AppSpacing.md),
                    OrderCancelSection(
                      controller: _reasonController,
                      showReasonInput: _showReasonInput,
                      isCancelling: _isCancelling,
                      warnBeforeCancel: _warnBeforeCancelStatuses.contains(
                        order.status,
                      ),
                      onShowReasonInput: () {
                        setState(() => _showReasonInput = true);
                      },
                      onCancel: _cancelOrder,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _cancelOrder() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      _showSnackBar(OrderDetailStrings.cancelReasonRequired);
      return;
    }

    if (_warnBeforeCancelStatuses.contains(widget.order.status)) {
      final confirmed = await _showCancelWarningDialog();
      if (!mounted || confirmed != true) return;
    }

    setState(() => _isCancelling = true);
    try {
      await ref
          .read(customerOrderServiceProvider)
          .cancelOrder(widget.order.id, widget.customerId, statusNote: reason);
      ref.invalidate(customerOrdersProvider(widget.customerId));
      ref.invalidate(orderByIdProvider(widget.order.id));
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(OrderDetailStrings.cancelledSuccess),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      final message = error.toString().contains('Không thể hủy')
          ? OrderDetailStrings.cancelInProgressFailure
          : OrderDetailStrings.cancelFailure;
      _showSnackBar(message);
    }
  }

  Future<bool?> _showCancelWarningDialog() {
    final warning = widget.order.status == 'picking_up'
        ? OrderDetailStrings.cancelPickingUpWarning
        : OrderDetailStrings.cancelAssignedWarning;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(AppSpacing.screenH),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: AppRadius.xl2,
              boxShadow: AppShadow.elevated,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: AppRadius.md,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  OrderDetailStrings.cancelConfirmTitle,
                  style: AppTextStyles.headingMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  warning,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: _DialogAction(
                        label: OrderDetailStrings.keepOrderAction,
                        onTap: () => Navigator.of(dialogContext).pop(false),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _DialogAction(
                        label: OrderDetailStrings.continueCancelAction,
                        color: AppColors.error,
                        onTap: () => Navigator.of(dialogContext).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: AppRadius.full,
        ),
      ),
    );
  }
}

class _DialogAction extends StatelessWidget {
  const _DialogAction({
    required this.label,
    required this.onTap,
    this.color = AppColors.textSecondary,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color == AppColors.error ? AppColors.error : AppColors.bgLight,
      borderRadius: AppRadius.full,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.full,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelMedium.copyWith(
              color: color == AppColors.error ? AppColors.textOnAccent : color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
