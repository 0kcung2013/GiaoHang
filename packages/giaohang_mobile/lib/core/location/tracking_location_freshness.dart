/// Ưu tiên Broadcast đang hoạt động; PG chỉ dự phòng sau khoảng im lặng.
/// Timestamp riêng từng gói tiếp tục chặn sự kiện cũ/trùng khi nhận lại.
class TrackingLocationFreshness {
  TrackingLocationFreshness({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const broadcastFreshFor = Duration(seconds: 6);

  final DateTime Function() _clock;
  DateTime? _latestSampleAt;
  DateTime? _latestBroadcastAt;
  DateTime? _lastBroadcastReceivedAt;
  Duration? _sampleInterval;
  int _revision = 0;

  int get revision => _revision;
  DateTime? get latestSampleAt => _latestSampleAt;
  Duration? get sampleInterval => _sampleInterval;

  bool acceptBroadcast({required DateTime sampledAt}) {
    if (_latestBroadcastAt != null && !sampledAt.isAfter(_latestBroadcastAt!)) {
      return false;
    }
    if (_latestSampleAt != null && sampledAt.isBefore(_latestSampleAt!)) {
      return false;
    }
    _latestBroadcastAt = sampledAt;
    _lastBroadcastReceivedAt = _clock();
    _recordSample(sampledAt);
    return true;
  }

  bool acceptPersisted({required DateTime? sampledAt}) {
    // location_updated_at là giờ ghi PG. Mẫu tọa độ cũ có thể được ghi sau
    // Broadcast mới vì network/monitoring delay; ưu tiên luồng đang hoạt động.
    final lastBroadcast = _lastBroadcastReceivedAt;
    if (lastBroadcast != null &&
        _clock().difference(lastBroadcast) < broadcastFreshFor) {
      return false;
    }
    if (_latestSampleAt != null &&
        (sampledAt == null || !sampledAt.isAfter(_latestSampleAt!))) {
      return false;
    }
    _recordSample(sampledAt);
    return true;
  }

  bool acceptProfilePoll({required int startedAtRevision}) {
    // The public profile RPC has coordinates but no GPS capture timestamp.
    // It can seed tracking, but cannot supersede a timestamped live sample.
    if (startedAtRevision != _revision || _latestSampleAt != null) return false;
    _revision++;
    return true;
  }

  void _recordSample(DateTime? sampledAt) {
    final previous = _latestSampleAt;
    if (previous != null && sampledAt != null && sampledAt.isAfter(previous)) {
      _sampleInterval = sampledAt.difference(previous);
    }
    _latestSampleAt = sampledAt;
    _revision++;
  }
}
