import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../../../../order_help/data/customer_support_ticket_repository.dart';
import '../../../../reviews/widgets/order_review_section.dart';
import '../../../../risk_reports/data/participant_risk_report_query_repository.dart';
import '../../../widgets/delivery_proof/customer_delivery_proof_section.dart';
import '../../tracking/widgets/assigned_driver_card.dart';
import '../order_helpers.dart';
import 'order_detail_strings.dart';
import 'widgets/order_cancel_section.dart';
import 'widgets/order_detail_activity.dart';
import 'widgets/order_detail_header.dart';
import 'widgets/order_detail_information.dart';
import 'widgets/order_tracking_action.dart';
import 'widgets/order_print_label_action.dart';
import 'widgets/order_risk_report_section.dart';

const orderDetailSheetKey = Key('order-detail-sheet');

void showOrderDetailSheet({
  required BuildContext context,
  required String customerId,
  required OrderModel order,
  ParticipantSupportTicketRepository? supportRepository,
  ParticipantRiskReportQueryRepository? riskRepository,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => OrderDetailSheet(
      customerId: customerId,
      order: order,
      supportRepository: supportRepository,
      riskRepository: riskRepository,
    ),
  );
}

class OrderDetailSheet extends ConsumerStatefulWidget {
  const OrderDetailSheet({
    super.key,
    required this.customerId,
    required this.order,
    this.supportRepository,
    this.riskRepository,
  });

  final String customerId;
  final OrderModel order;
  final ParticipantSupportTicketRepository? supportRepository;
  final ParticipantRiskReportQueryRepository? riskRepository;

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
  static const _riskyCancellationStatuses = {'assigned', 'picking_up'};

  final _reasonController = TextEditingController();
  bool _showReasonInput = false;
  bool _isCancelling = false;
  String? _cancellationError;
  ScrollController? _sheetScrollController;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final canCancel =
        _cancellableStatuses.contains(order.status) &&
        order.actualPickedUpAt == null;
    final cancellationLockedReason =
        order.actualPickedUpAt != null &&
            _cancellableStatuses.contains(order.status)
        ? OrderDetailStrings.cancelPickupLockedDescription
        : order.status == 'delivering'
        ? OrderDetailStrings.cancelLockedDescription
        : null;
    final note = order.note?.trim();

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.58,
      maxChildSize: 0.97,
      expand: false,
      builder: (context, scrollController) {
        _sheetScrollController = scrollController;
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
                  if (order.trackingCode.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    OrderTrackingAction(onPressed: _openTracking),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  OrderPrintLabelAction(order: order),
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
                  const SizedBox(height: AppSpacing.md),
                  OrderRiskReportSection(
                    order: order,
                    supportRepository: widget.supportRepository,
                    riskRepository: widget.riskRepository,
                  ),
                  if (canCancel || cancellationLockedReason != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    OrderCancelSection(
                      controller: _reasonController,
                      showReasonInput: _showReasonInput,
                      isCancelling: _isCancelling,
                      warnBeforeCancel: _riskyCancellationStatuses.contains(
                        order.status,
                      ),
                      errorMessage: _cancellationError,
                      disabledReason: cancellationLockedReason,
                      onShowReasonInput: _showCancellationReasonInput,
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

  void _openTracking() {
    final code = widget.order.trackingCode.trim();
    if (code.isEmpty) return;
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go('/customer-home?tab=tracking&code=${Uri.encodeComponent(code)}');
  }

  void _showCancellationReasonInput() {
    setState(() {
      _showReasonInput = true;
      _cancellationError = null;
    });
    _scrollToCancellationAction();
  }

  void _scrollToCancellationAction() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scrollController = _sheetScrollController;
      if (!mounted ||
          scrollController == null ||
          !scrollController.hasClients) {
        return;
      }
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: AppDuration.normal,
        curve: AppCurve.decelerate,
      );
    });
  }

  Future<void> _cancelOrder() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() {
        _cancellationError = OrderDetailStrings.cancelReasonRequired;
      });
      _scrollToCancellationAction();
      return;
    }

    setState(() {
      _isCancelling = true;
      _cancellationError = null;
    });
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
      setState(() {
        _isCancelling = false;
        final message = OrderDetailStrings.cancellationFailureMessage(error);
        _cancellationError = kDebugMode
            ? '$message\nChi tiết kỹ thuật: $error'
            : message;
      });
      _scrollToCancellationAction();
    }
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
