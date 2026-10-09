import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../core/models/order_model.dart';
import '../../../finance/models/driver_goods_deposit.dart';
import '../../home/utils/driver_home_formatters.dart';
import '../../home/widgets/driver_order_offer_summary.dart';
import 'driver_order_details_content.dart';

/// Giữ map và thanh nghiệp vụ mounted khi chuyển giữa MAP / thông tin đơn.
class DriverOrderDetailsLayout extends StatefulWidget {
  const DriverOrderDetailsLayout({
    super.key,
    required this.order,
    required this.mapBuilder,
    required this.footer,
    required this.onBack,
    required this.helpAction,
    required this.status,
    this.notice,
    this.cancellationAction,
    this.goodsDeposit,
  });

  final OrderModel order;
  final Widget Function(VoidCallback onBack) mapBuilder;
  final Widget footer;
  final VoidCallback onBack;
  final Widget helpAction;
  final Widget status;
  final Widget? notice;
  final Widget? cancellationAction;
  final DriverGoodsDeposit? goodsDeposit;

  @override
  State<DriverOrderDetailsLayout> createState() =>
      _DriverOrderDetailsLayoutState();
}

class _DriverOrderDetailsLayoutState extends State<DriverOrderDetailsLayout> {
  bool _showMap = false;

  void _back() {
    if (_showMap) {
      setState(() => _showMap = false);
    } else {
      widget.onBack();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_showMap,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && _showMap) setState(() => _showMap = false);
    },
    child: Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Column(
        children: [
          if (!_showMap)
            Material(
              color: AppColors.bgCard,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: DriverOrderPresentationStrings.back,
                        onPressed: _back,
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DriverOrderPresentationStrings.details,
                              style: AppTextStyles.headingSmall,
                            ),
                            Text(
                              displayOrderCode(widget.order),
                              style: AppTextStyles.mono.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      TextButton.icon(
                        key: const ValueKey('driver-open-map'),
                        onPressed: () => setState(() => _showMap = true),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.info,
                          backgroundColor: AppColors.info.withValues(
                            alpha: 0.08,
                          ),
                          minimumSize: const Size(48, 48),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.md,
                          ),
                          textStyle: AppTextStyles.labelMedium,
                        ),
                        icon: const Icon(Icons.map_rounded, size: 20),
                        label: const Text(DriverOrderPresentationStrings.map),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      widget.helpAction,
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Offstage(offstage: !_showMap, child: widget.mapBuilder(_back)),
                if (!_showMap)
                  DriverOrderDetailsContent(
                    order: widget.order,
                    status: widget.status,
                    notice: widget.notice,
                    cancellationAction: widget.cancellationAction,
                    goodsDeposit: widget.goodsDeposit,
                  ),
              ],
            ),
          ),
          SafeArea(top: false, child: widget.footer),
        ],
      ),
    ),
  );
}
