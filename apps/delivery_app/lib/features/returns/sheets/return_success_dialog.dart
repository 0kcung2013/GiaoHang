import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

Future<void> showReturnSuccessDialog(
  BuildContext context, {
  required int driverEarning,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(
        Icons.check_circle_rounded,
        color: AppColors.success,
        size: 44,
      ),
      title: const Text('Hoàn đơn thành công'),
      content: Text(
        'Thu nhập hoàn hàng ${formatVnd(driverEarning)} đã được ghi nhận.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Xong'),
        ),
      ],
    ),
  );
}
