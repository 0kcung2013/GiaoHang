import '../../offer_transfer/models/driver_offer_transfer_state.dart';

/// Đồng hồ tiến theo elapsed time từ giờ server, không phụ thuộc giờ máy.
class DriverAcceptanceState {
  DriverAcceptanceState({
    required this.serverNow,
    this.lockedUntil,
    this.lockReason,
    this.transfers,
  }) : _elapsed = Stopwatch()..start();

  final DateTime serverNow;
  final DateTime? lockedUntil;
  final String? lockReason;
  final DriverOfferTransferState? transfers;
  final Stopwatch _elapsed;

  DateTime now() => serverNow.add(_elapsed.elapsed);
  bool get isLocked => lockedUntil?.isAfter(now()) ?? false;

  DateTime? get nextRefreshAt {
    final candidates =
        [lockedUntil, transfers?.nextExpiryAt]
            .whereType<DateTime>()
            .where((deadline) => deadline.isAfter(now()))
            .toList()
          ..sort();
    return candidates.isEmpty ? null : candidates.first;
  }

  factory DriverAcceptanceState.fromJson(Map<String, dynamic> json) {
    final serverNow = DateTime.parse(json['server_now'] as String);
    return DriverAcceptanceState(
      serverNow: serverNow,
      lockedUntil: DateTime.tryParse(json['locked_until']?.toString() ?? ''),
      lockReason: json['lock_reason'] as String?,
      transfers: json['transfer_count'] is num
          ? DriverOfferTransferState.fromJson(json)
          : null,
    );
  }
}
