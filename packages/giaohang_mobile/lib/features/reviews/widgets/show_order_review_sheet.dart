import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../core/models/order_model.dart';
import '../../../core/providers/customer_providers.dart';
import '../../../core/services/review_service.dart';
import '../review_strings.dart';
import 'review_form_sheet.dart';

// Chặn mở nhiều sheet cho cùng đơn khi người dùng chạm liên tiếp lúc đang đọc.
final _opening = Expando<Set<String>>();

Future<bool?> showOrderReviewSheet({
  required BuildContext context,
  required OrderModel order,
  required String direction,
  String? recipientName,
}) async {
  if (order.status != 'delivered' || order.driverId?.isNotEmpty != true) {
    return false;
  }
  final navigator = Navigator.of(context);
  final active = _opening[navigator] ??= <String>{};
  final key = '${order.id}:$direction';
  if (!active.add(key)) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final service = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(reviewServiceProvider);
    final existing = await service.getReviewByOrderId(
      order.id,
      direction: direction,
    );
    if (!context.mounted) return false;
    if (existing != null) {
      messenger.showSnackBar(
        const SnackBar(content: Text(ReviewStrings.alreadyRecorded)),
      );
      return false;
    }
    return await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      constraints: const BoxConstraints(maxWidth: 560),
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.lg.topLeft),
      ),
      builder: (_) => ReviewFormSheet(
        order: order,
        direction: direction,
        recipientName: recipientName,
      ),
    );
  } catch (_) {
    if (messenger.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text(ReviewService.loadError)),
      );
    }
    return false;
  } finally {
    active.remove(key);
  }
}
