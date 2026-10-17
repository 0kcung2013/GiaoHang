import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/models/order_finance.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/services/customer_order_payment_service.dart';
import '../utils/order_payment_strings.dart';

typedef FinishPaidOrder =
    Future<void> Function(
      CustomerOrderPaymentSession session,
      OrderModel order,
    );

/// Chỉ hoàn tất đơn sau khi backend xác nhận thanh toán; mở URL không phải
/// bằng chứng đã trả tiền. Các lần thử lại dùng cùng snapshot và phiên còn hạn.
class OrderConfirmationPaymentController extends ChangeNotifier {
  OrderConfirmationPaymentController({
    required this.service,
    required this.onPaid,
    Future<bool> Function(Uri)? openPayment,
    this.pollInterval = const Duration(seconds: 3),
  }) : _openPayment = openPayment ?? _launchPayment;

  final CustomerOrderPaymentService service;
  final FinishPaidOrder onPaid;
  final Duration pollInterval;
  final Future<bool> Function(Uri) _openPayment;
  CustomerOrderPaymentSession? _session;
  Uri? _paymentUrl;
  OrderModel? _order;
  Timer? _pollTimer;
  Future<void>? _checking;
  bool _submitting = false;
  bool _completing = false;
  bool _completed = false;
  bool _disposed = false;
  String? _error;

  CustomerOrderPaymentSession? get session => _session;
  OrderModel? get orderSnapshot => _order;
  String? get error => _error;
  bool get isBusy => _submitting || _completing;
  bool get isChecking => _checking != null;
  bool get hasActiveSession =>
      _session != null &&
      (!_session!.isTerminal || _session!.status == OrderPaymentStatus.paid);

  Future<void> submit(OrderModel order) async {
    if (_disposed || isBusy || _completed) return;
    _submitting = true;
    _error = null;
    _notify();
    try {
      if (_session != null) {
        await refresh();
        if (_session?.status == OrderPaymentStatus.paid) return;
      }
      if (_disposed || _completed) return;
      if (_session == null ||
          _session!.status == OrderPaymentStatus.failed ||
          _session!.status == OrderPaymentStatus.expired) {
        _order = order;
        _session = await service.createPaymentSession(order);
        if (_disposed) return;
        _paymentUrl = _session!.paymentUrl;
        _error = null;
      }
      if (_session!.isPaid) {
        await _finish();
        return;
      }
      if (_session!.isTerminal) {
        _error = _terminalMessage(_session!.status);
        return;
      }
      _pollTimer ??= Timer.periodic(pollInterval, (_) => unawaited(refresh()));
      final uri = _session!.paymentUrl ?? _paymentUrl;
      if (uri == null || !await _openPayment(uri)) {
        _error = OrderPaymentText.paymentUnavailable;
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      _submitting = false;
      _notify();
    }
  }

  Future<void> refresh() async {
    if (_disposed || _session == null || _completed) return;
    if (_checking != null) return _checking;
    _checking = _refresh();
    _notify();
    try {
      await _checking;
    } finally {
      _checking = null;
      _notify();
    }
  }

  Future<void> _refresh() async {
    try {
      final updated = await service.getPaymentSession(_session!.sessionId);
      if (_disposed) return;
      _session = updated;
      _error = null;
      if (updated.isPaid) {
        await _finish();
      } else if (updated.status == OrderPaymentStatus.paid) {
        // Không mở phiên mới khi đã thu tiền nhưng chưa trả về mã đơn.
        _error = OrderPaymentText.awaitingPayment;
      } else if (updated.isTerminal) {
        _pollTimer?.cancel();
        _pollTimer = null;
        _error = _terminalMessage(updated.status);
      }
    } catch (error) {
      _error = error.toString();
    }
  }

  Future<void> _finish() async {
    if (_disposed || _completed || _completing) return;
    _completing = true;
    _notify();
    try {
      await onPaid(_session!, _order!);
      _completed = true;
      _pollTimer?.cancel();
      _pollTimer = null;
    } finally {
      _completing = false;
      _notify();
    }
  }

  static String _terminalMessage(OrderPaymentStatus status) =>
      status == OrderPaymentStatus.expired
      ? OrderPaymentText.paymentExpired
      : OrderPaymentText.paymentFailed;

  static Future<bool> _launchPayment(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    super.dispose();
  }
}
