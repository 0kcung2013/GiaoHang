import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../services/return_route_quote_service.dart';
import '../widgets/support_return_quote_card.dart';

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
  final _reasonController = TextEditingController(text: 'delivery_incident');
  final _instructionController = TextEditingController();
  final ReturnFeePayer _feePayer = ReturnFeePayer.platform;
  ReturnRouteQuote? _quote;
  bool _quoting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateQuote());
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  Future<void> _calculateQuote() async {
    final order = widget.report.order;
    final lat = order.pickupLat;
    final lng = order.pickupLng;
    if (lat == null || lng == null || order.pickupAddress.trim().isEmpty) {
      setState(() => _error = 'Đơn hàng chưa có đủ tọa độ nơi lấy hàng.');
      return;
    }
    setState(() {
      _quoting = true;
      _error = null;
    });
    try {
      final quote = await widget.quoteService.quote(
        riskReportId: widget.report.id,
        order: widget.report.order,
        destinationLat: lat,
        destinationLng: lng,
      );
      if (mounted) setState(() => _quote = quote);
    } catch (error) {
      if (mounted) setState(() => _error = 'Không thể tính lộ trình: $error');
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl,
          boxShadow: AppShadow.elevated,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: AppRadius.md,
                    ),
                    child: const Icon(
                      Icons.keyboard_return_rounded,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phê duyệt hoàn đơn',
                          style: AppTextStyles.headingMedium,
                        ),
                        Text(
                          widget.report.order.trackingCode,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle('1', 'Lý do và chỉ dẫn'),
                    TextField(
                      controller: _reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Mã lý do',
                        border: OutlineInputBorder(borderRadius: AppRadius.md),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _instructionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Hướng dẫn cho tài xế',
                        border: OutlineInputBorder(borderRadius: AppRadius.md),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _sectionTitle('2', 'Điểm hoàn hàng'),
                    Container(
                      key: const Key('return-pickup-destination'),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.bgLight,
                        borderRadius: AppRadius.lg,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: AppColors.accentLight,
                              borderRadius: AppRadius.md,
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: AppColors.markerPickup,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hoàn về nơi lấy hàng',
                                  style: AppTextStyles.headingSmall,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  widget.report.order.pickupAddress,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Điểm hoàn được khóa theo thông tin đơn hàng.',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.outlined(
                            onPressed: _quoting ? null : _calculateQuote,
                            tooltip: 'Tính lại lộ trình hoàn',
                            icon: const Icon(Icons.route_rounded),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _sectionTitle('3', 'Chi phí và đối soát'),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.verified_user_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text('GiaoHang hỗ trợ phí hoàn'),
                      subtitle: Text(
                        'Phase 1 chưa thu thêm phí từ khách hàng. '
                        'Thu nhập chặng hoàn của tài xế do nền tảng chi trả.',
                      ),
                    ),
                    if (_quote != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      SupportReturnQuoteCard(
                        quote: _quote!,
                        payer: _feePayer,
                        deliveryFee: widget.report.order.deliveryFee,
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _error!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    key: const Key('approve-order-return'),
                    onPressed: _quote == null ? null : _submit,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Duyệt và gửi tài xế'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String step, String title) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnDark,
          child: Text(step),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(title, style: AppTextStyles.headingSmall),
      ],
    ),
  );

  void _submit() {
    final quote = _quote!;
    final order = widget.report.order;
    final returnFee = OrderReturnPricingPolicy.calculateReturnFee(
      order.deliveryFee,
    );
    Navigator.pop(
      context,
      ReturnApprovalDraft(
        reportId: widget.report.id,
        reasonCode: _reasonController.text.trim(),
        destinationType: ReturnDestinationType.sender,
        destinationAddress: order.pickupAddress.trim(),
        destinationLat: order.pickupLat!,
        destinationLng: order.pickupLng!,
        routeOriginLat: quote.originLat,
        routeOriginLng: quote.originLng,
        routeDistanceMeters: quote.distanceMeters,
        routeDurationSeconds: quote.durationSeconds,
        quoteSource: quote.source,
        feePayer: _feePayer,
        customerReturnCharge: 0,
        driverReturnEarning: returnFee,
        instruction: _instructionController.text.trim().isEmpty
            ? null
            : _instructionController.text.trim(),
      ),
    );
  }
}
