import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../core/models/order_model.dart';
import '../data/customer_support_ticket_repository.dart';
import '../models/order_help_option.dart';
import '../order_help_strings.dart';

Future<SupportTicket?> showCustomerSupportRequestSheet(
  BuildContext context, {
  required OrderModel order,
  required OrderHelpOption option,
  required CustomerSupportTicketRepository repository,
}) {
  return showModalBottomSheet<SupportTicket>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.primary.withValues(alpha: 0.42),
    builder: (_) => _CustomerSupportRequestSheet(
      order: order,
      option: option,
      repository: repository,
    ),
  );
}

class _CustomerSupportRequestSheet extends StatefulWidget {
  const _CustomerSupportRequestSheet({
    required this.order,
    required this.option,
    required this.repository,
  });

  final OrderModel order;
  final OrderHelpOption option;
  final CustomerSupportTicketRepository repository;

  @override
  State<_CustomerSupportRequestSheet> createState() =>
      _CustomerSupportRequestSheetState();
}

class _CustomerSupportRequestSheetState
    extends State<_CustomerSupportRequestSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _controller.text.trim();
    if (message.length < 10) {
      setState(() => _error = OrderHelpStrings.descriptionRequired);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final ticket = await widget.repository.create(
        SupportTicketDraft(
          customerId: widget.order.customerId,
          orderId: widget.order.id,
          subject: widget.option.label,
          message: message,
          priority: widget.option.priority,
        ),
      );
      if (mounted) Navigator.pop(context, ticket);
    } on CustomerSupportTicketException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa thể gửi yêu cầu. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: AppShadow.elevated,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.bgWarm,
                        borderRadius: AppRadius.md,
                      ),
                      child: Icon(widget.option.icon, color: AppColors.primary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.option.label,
                            style: AppTextStyles.headingMedium,
                          ),
                          Text(
                            widget.order.trackingCode,
                            style: AppTextStyles.mono.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.pop(context),
                      tooltip: OrderHelpStrings.close,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  OrderHelpStrings.detailTitle,
                  style: AppTextStyles.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  OrderHelpStrings.detailHint,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('customer-support-message'),
                  controller: _controller,
                  enabled: !_submitting,
                  autofocus: true,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: 4000,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: InputDecoration(
                    hintText: OrderHelpStrings.descriptionPlaceholder,
                    errorText: _error,
                    filled: true,
                    fillColor: AppColors.bgLight,
                    border: const OutlineInputBorder(
                      borderRadius: AppRadius.md,
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
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  key: const Key('submit-customer-support-ticket'),
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.textOnAccent,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.md,
                    ),
                  ),
                  icon: Icon(
                    _submitting
                        ? Icons.cloud_upload_outlined
                        : Icons.send_rounded,
                  ),
                  label: Text(
                    _submitting
                        ? OrderHelpStrings.sending
                        : OrderHelpStrings.sendSupport,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
