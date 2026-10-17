enum DriverCancellationReason { storeClosed, personal }

/// Thời hạn do server cấp; không khởi động lại khi đóng/mở sheet.
class DriverCancellationPolicy {
  const DriverCancellationPolicy({
    required this.status,
    required this.pickupConfirmed,
    this.pickupArrivedAt,
  });

  static const storeWait = Duration(minutes: 10);
  static const personalLock = Duration(minutes: 30);

  final String status;
  final bool pickupConfirmed;
  final DateTime? pickupArrivedAt;

  bool get canCancel =>
      (status == 'assigned' || status == 'picking_up') && !pickupConfirmed;

  DateTime? get storeEligibleAt => pickupArrivedAt?.add(storeWait);

  bool allows(DriverCancellationReason reason, DateTime now) {
    if (!canCancel) return false;
    if (reason == DriverCancellationReason.personal) return true;
    final deadline = storeEligibleAt;
    return deadline != null && !now.isBefore(deadline);
  }

  static Duration remaining(DateTime deadline, DateTime now) {
    final difference = deadline.difference(now);
    return difference.isNegative ? Duration.zero : difference;
  }

  static String formatRemaining(Duration duration) {
    // Làm tròn lên để không hiển thị 00:00 khi thời hạn chưa kết thúc.
    final seconds = (duration.inMilliseconds / 1000).ceil().clamp(0, 999999);
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
