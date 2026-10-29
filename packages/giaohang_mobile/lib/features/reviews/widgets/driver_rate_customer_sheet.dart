import 'package:flutter/material.dart';

import '../../../core/models/order_model.dart';
import '../../../core/models/review_model.dart';
import 'show_order_review_sheet.dart';

Future<bool?> showDriverRateCustomerSheet({
  required BuildContext context,
  required OrderModel order,
  String? customerName,
}) => showOrderReviewSheet(
  context: context,
  order: order,
  direction: ReviewDirection.driverToCustomer,
  recipientName: customerName,
);
