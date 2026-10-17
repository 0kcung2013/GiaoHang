import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../core/models/order_model.dart';
import 'free_pick_order_panel.dart';

class FreePickOrderCarousel extends StatefulWidget {
  const FreePickOrderCarousel({
    super.key,
    required this.orders,
    required this.selectedOrderId,
    required this.isClaiming,
    required this.onSelected,
    required this.onClaim,
    this.driverLat,
    this.driverLng,
  });

  final List<OrderModel> orders;
  final String? selectedOrderId;
  final bool isClaiming;
  final ValueChanged<OrderModel> onSelected;
  final ValueChanged<OrderModel> onClaim;
  final double? driverLat;
  final double? driverLng;

  @override
  State<FreePickOrderCarousel> createState() => _FreePickOrderCarouselState();
}

class _FreePickOrderCarouselState extends State<FreePickOrderCarousel> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: _selectedIndex(),
      viewportFraction: 0.94,
    );
  }

  @override
  void didUpdateWidget(covariant FreePickOrderCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedOrderId == widget.selectedOrderId &&
        oldWidget.orders.length == widget.orders.length) {
      return;
    }
    final target = _selectedIndex();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final current = _controller.page?.round();
      if (current == target) return;
      _controller.animateToPage(
        target,
        duration: AppDuration.normal,
        curve: AppCurve.decelerate,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final scaledExtra = ((textScale - 1).clamp(0.0, 0.6) * 64).toDouble();
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SizedBox(
      key: const Key('free-pick-order-carousel'),
      height: 272 + scaledExtra + bottomInset,
      child: PageView.builder(
        key: const Key('free-pick-order-page-view'),
        controller: _controller,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.orders.length,
        onPageChanged: (index) {
          if (index < 0 || index >= widget.orders.length) return;
          final order = widget.orders[index];
          if (order.id != widget.selectedOrderId) widget.onSelected(order);
        },
        itemBuilder: (context, index) {
          final order = widget.orders[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FreePickOrderPanel(
                order: order,
                isClaiming:
                    widget.isClaiming && order.id == widget.selectedOrderId,
                onClaim: () => widget.onClaim(order),
                driverLat: widget.driverLat,
                driverLng: widget.driverLng,
                position: index + 1,
                totalCount: widget.orders.length,
              ),
            ),
          );
        },
      ),
    );
  }

  int _selectedIndex() {
    final index = widget.orders.indexWhere(
      (order) => order.id == widget.selectedOrderId,
    );
    return index < 0 ? 0 : index;
  }
}
