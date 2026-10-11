import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../constants/return_approval_strings.dart';
import '../services/return_route_quote_service.dart';
import '../widgets/support_return_approval_content.dart';

Future<ReturnApprovalDraft?> showSupportReturnApprovalDialog({
  required BuildContext context,
  required RiskReport report,
  required ReturnRouteQuoteService quoteService,
}) {
  return showDialog<ReturnApprovalDraft>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SupportReturnApprovalDialog(
      report: report,
      quoteService: quoteService,
    ),
  );
}

class _SupportReturnApprovalDialog extends StatefulWidget {
  const _SupportReturnApprovalDialog({
    required this.report,
    required this.quoteService,
  });
  final RiskReport report;
  final ReturnRouteQuoteService quoteService;

  @override
  State<_SupportReturnApprovalDialog> createState() =>
      _SupportReturnApprovalDialogState();
}

class _SupportReturnApprovalDialogState
    extends State<_SupportReturnApprovalDialog> {
  final _instructionController = TextEditingController();
  final _scrollController = ScrollController();
  final _contentKey = GlobalKey();
  ReturnRouteQuote? _quote;
  bool _quoting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _calculateQuote();
    });
  }

  @override
  void dispose() {
    _instructionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _calculateQuote() async {
    final order = widget.report.order;
    final lat = order.pickupLat;
    final lng = order.pickupLng;
    if (lat == null || lng == null || order.pickupAddress.trim().isEmpty) {
      setState(() {
        _quote = null;
        _quoting = false;
        _error = ReturnApprovalStrings.missingPickup;
      });
      return;
    }
    setState(() {
      _quote = null;
      _quoting = true;
      _error = null;
    });
    try {
      final quote = await widget.quoteService.quote(
        riskReportId: widget.report.id,
        order: order,
        destinationLat: lat,
        destinationLng: lng,
      );
      if (mounted) setState(() => _quote = quote);
    } catch (_) {
      if (mounted) setState(() => _error = ReturnApprovalStrings.routeError);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.bgCard,
    surfaceTintColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
    clipBehavior: Clip.antiAlias,
    insetPadding: const EdgeInsets.all(AppSpacing.lg),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scrollWholeDialog = constraints.maxHeight < 260;
          final content = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ReturnApprovalStrings.title,
                            style: AppTextStyles.headingMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            widget.report.order.trackingCode,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: ReturnApprovalStrings.close,
                      icon: const Icon(Icons.close_rounded),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              if (scrollWholeDialog)
                _buildContent()
              else
                Flexible(child: _buildContent()),
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        foregroundColor: AppColors.textSecondary,
                        textStyle: AppTextStyles.labelMedium,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.md,
                        ),
                      ),
                      child: const Text(ReturnApprovalStrings.cancel),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('approve-order-return'),
                        onPressed: _quote == null || _quoting || _error != null
                            ? null
                            : _submit,
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text(
                          ReturnApprovalStrings.approve,
                          textAlign: TextAlign.center,
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.textOnAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          textStyle: AppTextStyles.labelLarge,
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.md,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          return scrollWholeDialog
              ? SingleChildScrollView(child: content)
              : content;
        },
      ),
    ),
  );

  Widget _buildContent() => Scrollbar(
    key: _contentKey,
    controller: _scrollController,
    thumbVisibility: true,
    child: SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SupportReturnApprovalContent(
        order: widget.report.order,
        quote: _quote,
        quoting: _quoting,
        error: _error,
        instructionController: _instructionController,
        onRecalculate: _calculateQuote,
      ),
    ),
  );

  void _submit() {
    if (_quote == null || _quoting || _error != null) return;
    final quote = _quote!;
    final order = widget.report.order;
    final returnFee = OrderReturnPricingPolicy.calculateReturnFee(
      order.deliveryFee,
    );
    Navigator.pop(
      context,
      ReturnApprovalDraft(
        reportId: widget.report.id,
        reasonCode: ReturnApprovalStrings.defaultReasonCode,
        destinationType: ReturnDestinationType.sender,
        destinationAddress: order.pickupAddress.trim(),
        destinationLat: order.pickupLat!,
        destinationLng: order.pickupLng!,
        routeOriginLat: quote.originLat,
        routeOriginLng: quote.originLng,
        routeDistanceMeters: quote.distanceMeters,
        routeDurationSeconds: quote.durationSeconds,
        quoteSource: quote.source,
        feePayer: ReturnFeePayer.platform,
        customerReturnCharge: 0,
        driverReturnEarning: returnFee,
        instruction: _instructionController.text.trim().isEmpty
            ? null
            : _instructionController.text.trim(),
      ),
    );
  }
}
