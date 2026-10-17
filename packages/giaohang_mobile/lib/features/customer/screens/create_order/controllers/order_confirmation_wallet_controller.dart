import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../../core/services/customer_order_payment_service.dart';
import '../utils/order_payment_strings.dart';

/// Giữ snapshot và mã yêu cầu sau lỗi mạng; bước hoàn tất lỗi không thu tiền lại.
class OrderConfirmationWalletController extends ChangeNotifier {
  OrderConfirmationWalletController({
    required this.service,
    required this.onCreated,
    String? requestId,
  }) : requestId = requestId ?? const Uuid().v4();

  final CustomerOrderPaymentService service;
  final Future<void> Function(OrderModel) onCreated;
  final String requestId;
  OrderModel? _snapshot;
  OrderModel? _created;
  bool _busy = false;
  bool _completed = false;
  bool _disposed = false;
  bool _insufficient = false;
  String? _error;

  bool get isBusy => _busy;
  bool get hasAttempt => _snapshot != null;
  bool get canSwitchPayment => !hasAttempt || _insufficient;
  OrderModel? get orderSnapshot => _snapshot;
  String? get error => _error;

  Future<void> submit(OrderModel order) async {
    if (_disposed || _busy || _completed) return;
    _snapshot ??= order;
    _busy = true;
    _error = null;
    _notify();
    try {
      _created ??= await service.createWalletOrder(
        _snapshot!,
        requestId: requestId,
      );
      _insufficient = false;
      if (_disposed) return;
      await onCreated(_created!);
      _completed = true;
    } catch (error) {
      _insufficient =
          error is CustomerWalletOrderPaymentException &&
          error.insufficientBalance;
      _error = error is CustomerWalletOrderPaymentException
          ? error.message
          : OrderPaymentText.walletRetry;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
