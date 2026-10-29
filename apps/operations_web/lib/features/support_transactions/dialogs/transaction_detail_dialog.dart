import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../support_orders/data/support_order_repository.dart';
import '../../support_orders/dialogs/support_order_detail_dialog.dart';
import '../constants/transaction_strings.dart';
import '../data/transaction_repository.dart';
import '../models/support_transaction.dart';
import '../utils/transaction_ui.dart';
import '../widgets/transaction_facts.dart';
import '../widgets/transaction_status.dart';
import 'transaction_request_dialog.dart';

class TransactionDetailDialog extends StatefulWidget {
  const TransactionDetailDialog({
    required this.transaction,
    required this.repository,
    required this.serverNow,
    this.orderRepository,
    super.key,
  });
  final SupportTransaction transaction;
  final TransactionRepository repository;
  final SupportOrderRepository? orderRepository;
  final DateTime serverNow;
  @override
  State<TransactionDetailDialog> createState() =>
      _TransactionDetailDialogState();
}

class _TransactionDetailDialogState extends State<TransactionDetailDialog> {
  late Future<List<TransactionRequest>?> _requests;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _requests = _loadRequests();
  }

  Future<List<TransactionRequest>?> _loadRequests() async {
    try {
      return await widget.repository.fetchRequests(widget.transaction);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openOrder() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final order = await widget.repository.fetchOrder(
        widget.transaction.orderId!,
      );
      if (!mounted) return;
      await showSupportOrderDetailDialog(
        context,
        order: order,
        repository:
            widget.orderRepository ??
            SupabaseSupportOrderRepository(Supabase.instance.client),
      );
    } catch (_) {
      if (mounted) setState(() => _error = TransactionStrings.orderError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createRequest() async {
    final draft = await showTransactionRequestDialog(
      context,
      widget.transaction,
    );
    if (!mounted || draft == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.createRequest(draft);
      if (!mounted) return;
      setState(() {
        _requests = _loadRequests();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(TransactionStrings.createdRequest)),
      );
    } catch (_) {
      if (mounted) setState(() => _error = TransactionStrings.createError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 800),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TransactionStrings.detail,
                          style: AppTextStyles.headingSmall,
                        ),
                        Text(
                          TransactionUi.kind(tx),
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: TransactionStrings.close,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: AppSpacing.lg,
                      runSpacing: AppSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          TransactionUi.money(tx.amount),
                          style: AppTextStyles.displayMedium,
                        ),
                        TransactionStatus(tx.status),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl2),
                    TransactionFacts(
                      transaction: tx,
                      serverNow: widget.serverNow,
                    ),
                    const SizedBox(height: AppSpacing.xl2),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        if (tx.orderId != null)
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _openOrder,
                            icon: const Icon(Icons.inventory_2_outlined),
                            label: Text(
                              tx.trackingCode ?? TransactionStrings.openOrder,
                            ),
                          ),
                        FilledButton.icon(
                          onPressed: _busy ? null : _createRequest,
                          icon: const Icon(Icons.add_comment_outlined),
                          label: const Text(TransactionStrings.request),
                        ),
                      ],
                    ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.md),
                        child: LinearProgressIndicator(color: AppColors.accent),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: Text(
                          _error!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl2),
                    Text(
                      TransactionStrings.requests,
                      style: AppTextStyles.headingSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FutureBuilder<List<TransactionRequest>?>(
                      future: _requests,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const LinearProgressIndicator(
                            color: AppColors.accent,
                          );
                        }
                        if (snapshot.hasError || snapshot.data == null) {
                          return TextButton.icon(
                            onPressed: () => setState(() {
                              _requests = _loadRequests();
                            }),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text(TransactionStrings.requestError),
                          );
                        }
                        final requests = snapshot.data!;
                        if (requests.isEmpty) {
                          return Text(
                            TransactionStrings.noRequests,
                            style: AppTextStyles.bodySmall,
                          );
                        }
                        return Column(
                          children: [
                            for (final request in requests)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.forum_outlined),
                                title: Text(
                                  request.subject,
                                  style: AppTextStyles.labelMedium,
                                ),
                                subtitle: Text(
                                  TransactionUi.status(request.status),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: () {
                                  final router = GoRouter.of(context);
                                  Navigator.pop(context);
                                  router.push('/support-ticket/${request.id}');
                                },
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
