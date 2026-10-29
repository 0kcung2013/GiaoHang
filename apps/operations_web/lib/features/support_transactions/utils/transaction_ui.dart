import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../../support_orders/utils/support_order_ui.dart';
import '../constants/transaction_strings.dart';
import '../models/support_transaction.dart';

abstract final class TransactionUi {
  static String group(TransactionGroup value) => switch (value) {
    TransactionGroup.topups => TransactionStrings.topups,
    TransactionGroup.payments => TransactionStrings.payments,
    TransactionGroup.refunds => TransactionStrings.refunds,
  };
  static String kind(SupportTransaction tx) => switch (tx.kind) {
    'vnpay_topup' => 'Nạp ví tài xế',
    'delivery_fee_payment' => 'Trả phí giao bằng ví',
    'delivery_fee_refund' => 'Hoàn phí giao vào ví',
    'platform_fee_capture' => 'Thu phí sàn tài xế',
    'customer_platform_fee_capture' => 'Nộp phí sàn đã thu từ khách',
    'cod_release' =>
      tx.purpose == 'paid_goods_deposit'
          ? 'Hoàn tiền làm tin'
          : 'Hoàn khoản giữ COD',
    'order_payment' => 'Thanh toán đơn qua VNPAY',
    _ => 'Giao dịch',
  };
  static String status(String value) => switch (value) {
    'pending' => 'Đang chờ',
    'completed' => 'Thành công',
    'failed' => 'Thất bại',
    'expired' => 'Hết hạn',
    'refund_required' => 'Cần hoàn tiền',
    'refunded' => 'Đã hoàn tiền',
    'reversed' => 'Đã đảo giao dịch',
    'resolved' => 'Đã giải quyết',
    'closed' => 'Đã đóng',
    'open' => 'Mới',
    'in_progress' => 'Đang xử lý',
    _ => 'Chưa xác định',
  };
  static Color statusColor(String value) => switch (value) {
    'completed' || 'refunded' => AppColors.success,
    'failed' => AppColors.error,
    'pending' || 'refund_required' => AppColors.warning,
    _ => AppColors.textSecondary,
  };
  static String money(int value) => formatVnd(value);
  static String delta(int? value) => value == null
      ? TransactionStrings.missing
      : '${value > 0 ? '+' : ''}${formatVnd(value)}';
  static String date(DateTime? value) => value == null
      ? TransactionStrings.missing
      : SupportOrderUi.formatDateTime(value.toLocal());
  static String source(String value) => switch (value) {
    'driver' => 'Ví tài xế',
    'customer' => 'Ví khách hàng',
    'vnpay' => 'VNPAY',
    _ => value,
  };
  static String paymentState(String? value) => switch (value) {
    'reserved' => 'Đã giữ phí',
    'settled' => 'Đã quyết toán',
    'refunded' => 'Đã hoàn phí',
    _ => TransactionStrings.missing,
  };
  static String reason(String? value) => switch (value) {
    'cancelled' => 'Hủy đơn',
    'assignment_timeout' => 'Hết thời gian tìm tài xế',
    'assignment_retry' => 'Tìm tài xế lại',
    'delivery' => 'Hoàn tất giao hàng',
    'return' => 'Hoàn tất trả hàng',
    'monitoring_revoke' => 'Thu hồi phân công',
    null || '' => TransactionStrings.missing,
    _ => value,
  };
}
