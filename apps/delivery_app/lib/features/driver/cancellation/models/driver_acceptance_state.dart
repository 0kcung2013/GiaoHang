/// Đồng hồ tiến theo elapsed time từ giờ server, không phụ thuộc giờ máy.
class DriverAcceptanceState {
  DriverAcceptanceState({required this.serverNow, this.lockedUntil})
    : _elapsed = Stopwatch()..start();

  final DateTime serverNow;
  final DateTime? lockedUntil;
  final Stopwatch _elapsed;

  DateTime now() => serverNow.add(_elapsed.elapsed);
  bool get isLocked => lockedUntil?.isAfter(now()) ?? false;

  factory DriverAcceptanceState.fromJson(Map<String, dynamic> json) {
    final serverNow = DateTime.parse(json['server_now'] as String);
    return DriverAcceptanceState(
      serverNow: serverNow,
      lockedUntil: DateTime.tryParse(json['locked_until']?.toString() ?? ''),
    );
  }
}
