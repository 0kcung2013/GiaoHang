import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

Future<void> showReturnSuccessDialog(
  BuildContext context, {
  required int returnFee,
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
        'Phí hoàn hàng ${formatVnd(returnFee)} đã được cộng vào Ví Tài Xế.',
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
