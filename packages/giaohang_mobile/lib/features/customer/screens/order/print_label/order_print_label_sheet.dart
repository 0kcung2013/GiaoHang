import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import 'order_print_label_controls.dart';
import 'order_print_label_strings.dart';
import 'order_shipping_label.dart';

export 'order_print_label_controls.dart'
    show orderPrintLabelButtonKey, orderPrintLabelCopiesKey;

const orderPrintLabelSheetKey = Key('order-print-label-sheet');

Future<void> showOrderPrintLabelSheet({
  required BuildContext context,
  required OrderModel order,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => OrderPrintLabelSheet(order: order),
  );
}

class OrderPrintLabelSheet extends StatefulWidget {
  const OrderPrintLabelSheet({super.key, required this.order});

  final OrderModel order;

  @override
  State<OrderPrintLabelSheet> createState() => _OrderPrintLabelSheetState();
}

class _OrderPrintLabelSheetState extends State<OrderPrintLabelSheet> {
  int _copies = 1;
  bool _isPrinting = false;
  bool _hasPrinted = false;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.96,
      minChildSize: 0.68,
      maxChildSize: 0.98,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          key: orderPrintLabelSheetKey,
          decoration: const BoxDecoration(
            color: AppColors.bgLight,
            borderRadius: AppRadius.xl2,
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.md,
                    AppSpacing.screenH,
                    AppSpacing.xl,
                  ),
                  children: [
                    const OrderPrintLabelSheetHandle(),
                    const SizedBox(height: AppSpacing.md),
                    OrderPrintLabelHeader(
                      onClose: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const OrderPrintLabelDemoNotice(),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.bgCard,
                            borderRadius: AppRadius.lg,
                            border: Border.all(color: AppColors.border),
                            boxShadow: AppShadow.elevated,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: OrderShippingLabel(order: widget.order),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OrderPrintLabelSettings(
                      copies: _copies,
                      onDecrease: _copies > 1
                          ? () => setState(() => _copies--)
                          : null,
                      onIncrease: _copies < 3
                          ? () => setState(() => _copies++)
                          : null,
                    ),
                  ],
                ),
              ),
              OrderPrintLabelActionBar(
                copies: _copies,
                isPrinting: _isPrinting,
                hasPrinted: _hasPrinted,
                onPrint: _simulatePrint,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _simulatePrint() async {
    if (_isPrinting) return;
    setState(() {
      _isPrinting = true;
      _hasPrinted = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _isPrinting = false;
      _hasPrinted = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(OrderPrintLabelStrings.printSuccess),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
