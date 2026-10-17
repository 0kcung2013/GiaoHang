/// Hạn mức do backend tính trên các đơn chuyển hoặc hết giờ trong 30 phút.
class DriverOfferTransferState {
  const DriverOfferTransferState({required this.count, this.nextExpiryAt});

  static const limit = 4;
  static const window = Duration(minutes: 30);
  static const lockDuration = Duration(minutes: 30);
  static const lockReason = 'offer_transfers';

  final int count;
  final DateTime? nextExpiryAt;

  int get remaining => (limit - count).clamp(0, limit);
  bool get isLastTransfer => remaining == 1;

  factory DriverOfferTransferState.fromJson(Map<String, dynamic> json) =>
      DriverOfferTransferState(
        count: (json['transfer_count'] as num).toInt(),
        nextExpiryAt: DateTime.tryParse(
          json['transfer_next_expiry_at']?.toString() ?? '',
        ),
      );
}
