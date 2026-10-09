import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../../core/models/order_model.dart';

/// Cập nhật riêng các thao tác đúng hạn, kể cả khi Realtime chưa đổi snapshot.
class DriverOfferExpiryBuilder extends StatefulWidget {
  const DriverOfferExpiryBuilder({
    super.key,
    required this.order,
    required this.now,
    required this.builder,
  });

  final OrderModel order;
  final DateTime Function()? now;
  final Widget Function(BuildContext context, bool expired) builder;

  @override
  State<DriverOfferExpiryBuilder> createState() =>
      _DriverOfferExpiryBuilderState();
}

class _DriverOfferExpiryBuilderState extends State<DriverOfferExpiryBuilder> {
  Timer? _expiry;

  DateTime? get _deadline {
    final offer = widget.order.offerExpiresAt;
    if (offer == null) return null;
    return offer.isBefore(widget.order.assignmentDeadline)
        ? offer
        : widget.order.assignmentDeadline;
  }

  bool get _expired =>
      widget.order.assignmentTimedOutAt != null ||
      _deadline == null ||
      (widget.now != null && !_deadline!.isAfter(widget.now!()));

  @override
  void initState() {
    super.initState();
    _scheduleExpiry();
  }

  @override
  void didUpdateWidget(covariant DriverOfferExpiryBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleExpiry();
  }

  void _scheduleExpiry() {
    _expiry?.cancel();
    if (_expired || widget.now == null) return;
    _expiry = Timer(_deadline!.difference(widget.now!()), () {
      if (!mounted) return;
      setState(() {});
      // Timer có thể chạy sớm một chút so với mốc thời gian.
      _scheduleExpiry();
    });
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _expired);
}
