import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_finance.dart';
import '../models/order_model.dart';
import '../models/order_submission_payload.dart';

typedef CustomerOrderPaymentFunctionInvoker =
    Future<dynamic> Function(String functionName, Map<String, dynamic> body);
typedef CustomerOrderPaymentRpcInvoker =
    Future<dynamic> Function(String functionName, Map<String, dynamic> params);

class CustomerOrderPaymentService {
  CustomerOrderPaymentService({
    SupabaseClient? client,
    CustomerOrderPaymentFunctionInvoker? functionInvoker,
    CustomerOrderPaymentRpcInvoker? rpcInvoker,
  }) : _functionInvoker = functionInvoker ?? _defaultFunction(client),
       _rpcInvoker = rpcInvoker ?? _defaultRpc(client);

  final CustomerOrderPaymentFunctionInvoker _functionInvoker;
  final CustomerOrderPaymentRpcInvoker _rpcInvoker;

  Future<CustomerOrderPaymentSession> createPaymentSession(
    OrderModel order,
  ) async {
    if (order.deliveryFeePayer != DeliveryFeePayer.sender) {
      throw const CustomerOrderPaymentException(
        'Đơn này không cần thanh toán VNPAY.',
      );
    }
    final response = await _functionInvoker(
      'vnpay-create-order-payment',
      buildOrderSubmissionPayload(order),
    );
    return CustomerOrderPaymentSession.fromJson(_singleRow(response));
  }

  Future<CustomerOrderPaymentSession> getPaymentSession(
    String sessionId,
  ) async {
    final response = await _rpcInvoker('get_customer_order_payment_session', {
      'p_session_id': sessionId,
    });
    return CustomerOrderPaymentSession.fromJson(_singleRow(response));
  }

  static CustomerOrderPaymentFunctionInvoker _defaultFunction(
    SupabaseClient? client,
  ) {
    final supabase = client ?? Supabase.instance.client;
    return (name, body) async {
      final response = await supabase.functions.invoke(name, body: body);
      if (response.status < 200 || response.status >= 300) {
        throw CustomerOrderPaymentException(
          'VNPAY trả về lỗi ${response.status}.',
        );
      }
      return response.data;
    };
  }

  static CustomerOrderPaymentRpcInvoker _defaultRpc(SupabaseClient? client) {
    final supabase = client ?? Supabase.instance.client;
    return (name, params) => supabase.rpc(name, params: params);
  }

  static Map<String, dynamic> _singleRow(dynamic response) {
    if (response is Map) return Map<String, dynamic>.from(response);
    if (response is List && response.length == 1 && response.single is Map) {
      return Map<String, dynamic>.from(response.single as Map);
    }
    throw const CustomerOrderPaymentException('Phiên thanh toán không hợp lệ.');
  }
}

class CustomerOrderPaymentSession {
  const CustomerOrderPaymentSession({
    required this.sessionId,
    required this.txnRef,
    required this.amount,
    required this.status,
    required this.expiresAt,
    this.paymentUrl,
    this.orderId,
    this.trackingCode,
  });

  final String sessionId;
  final String txnRef;
  final int amount;
  final OrderPaymentStatus status;
  final DateTime expiresAt;
  final Uri? paymentUrl;
  final String? orderId;
  final String? trackingCode;

  bool get isPaid => status == OrderPaymentStatus.paid && orderId != null;
  bool get isTerminal => const {
    OrderPaymentStatus.paid,
    OrderPaymentStatus.failed,
    OrderPaymentStatus.expired,
    OrderPaymentStatus.refundRequired,
    OrderPaymentStatus.refunded,
  }.contains(status);

  factory CustomerOrderPaymentSession.fromJson(Map<String, dynamic> json) {
    final sessionId = json['session_id']?.toString().trim() ?? '';
    final txnRef = json['txn_ref']?.toString().trim() ?? '';
    final amount = _parseInt(json['amount']);
    final expiresAt = DateTime.tryParse(json['expires_at']?.toString() ?? '');
    final rawUrl = json['payment_url']?.toString() ?? '';
    final paymentUrl = rawUrl.isEmpty ? null : Uri.tryParse(rawUrl);
    if (sessionId.isEmpty ||
        txnRef.isEmpty ||
        amount == null ||
        expiresAt == null) {
      throw const CustomerOrderPaymentException(
        'Dữ liệu phiên thanh toán không hợp lệ.',
      );
    }
    if (rawUrl.isNotEmpty &&
        (paymentUrl == null ||
            !paymentUrl.hasScheme ||
            paymentUrl.host.isEmpty)) {
      throw const CustomerOrderPaymentException('Liên kết VNPAY không hợp lệ.');
    }
    return CustomerOrderPaymentSession(
      sessionId: sessionId,
      txnRef: txnRef,
      amount: amount,
      status: OrderPaymentStatus.fromValue(json['status']),
      expiresAt: expiresAt,
      paymentUrl: paymentUrl,
      orderId: _optionalString(json['order_id']),
      trackingCode: _optionalString(json['tracking_code']),
    );
  }

  static int? _parseInt(Object? value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  static String? _optionalString(Object? value) {
    final normalized = value?.toString().trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

class CustomerOrderPaymentException implements Exception {
  const CustomerOrderPaymentException(this.message);

  final String message;

  @override
  String toString() => message;
}
