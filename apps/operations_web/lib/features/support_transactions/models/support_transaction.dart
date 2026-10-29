enum TransactionGroup { topups, payments, refunds }

class SupportTransaction {
  const SupportTransaction({
    required this.id,
    required this.source,
    required this.kind,
    required this.status,
    required this.amount,
    required this.userId,
    required this.createdAt,
    this.userName,
    this.userPhone,
    this.userRole,
    this.orderId,
    this.trackingCode,
    this.completedAt,
    this.expiresAt,
    this.providerRef,
    this.providerNo,
    this.responseCode,
    this.availableDelta,
    this.heldDelta,
    this.paymentState,
    this.purpose,
    this.reason,
  });
  final String id, source, kind, status, userId;
  final int amount;
  final DateTime createdAt;
  final String? userName, userPhone, userRole, orderId, trackingCode;
  final String? providerRef,
      providerNo,
      responseCode,
      paymentState,
      purpose,
      reason;
  final DateTime? completedAt, expiresAt;
  final int? availableDelta, heldDelta;
  String get key => '$source:$id';
  String get requestMarker => '[GD:$key]';
  String get displayReference => providerRef ?? id;
  String get displayUser =>
      userName?.trim().isNotEmpty == true ? userName! : userId;
  bool isOverdue(DateTime serverNow) =>
      status == 'pending' &&
      expiresAt != null &&
      expiresAt!.isBefore(serverNow);

  factory SupportTransaction.fromJson(Map<String, dynamic> row) =>
      SupportTransaction(
        id: row['id'] as String,
        source: row['source'] as String,
        kind: row['kind'] as String,
        status: row['status'] as String,
        amount: (row['amount'] as num).toInt(),
        userId: row['user_id'] as String,
        userName: row['user_name'] as String?,
        userPhone: row['user_phone'] as String?,
        userRole: row['user_role'] as String?,
        orderId: row['order_id'] as String?,
        trackingCode: row['tracking_code'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        completedAt: DateTime.tryParse(row['completed_at'] as String? ?? ''),
        expiresAt: DateTime.tryParse(row['expires_at'] as String? ?? ''),
        providerRef: row['provider_txn_ref'] as String?,
        providerNo: row['provider_transaction_no'] as String?,
        responseCode: row['provider_response_code'] as String?,
        availableDelta: (row['available_delta'] as num?)?.toInt(),
        heldDelta: (row['held_delta'] as num?)?.toInt(),
        paymentState: row['payment_state'] as String?,
        purpose: row['purpose'] as String?,
        reason: row['reason'] as String?,
      );
}

class TransactionPage {
  const TransactionPage({
    required this.rows,
    required this.hasMore,
    required this.serverNow,
  });
  final List<SupportTransaction> rows;
  final bool hasMore;
  final DateTime serverNow;
}

class TransactionRequest {
  const TransactionRequest({
    required this.id,
    required this.subject,
    required this.status,
  });
  final String id, subject, status;
}
