/// Orders the customer's broadcast and persisted GPS samples by capture time.
class TrackingLocationFreshness {
  DateTime? _latestSampleAt;
  int _revision = 0;

  int get revision => _revision;

  bool acceptBroadcast({required DateTime sampledAt}) {
    if (_latestSampleAt != null && sampledAt.isBefore(_latestSampleAt!)) {
      return false;
    }
    _latestSampleAt = sampledAt;
    _revision++;
    return true;
  }

  bool acceptPersisted({required DateTime? sampledAt}) {
    if (_latestSampleAt != null &&
        (sampledAt == null || !sampledAt.isAfter(_latestSampleAt!))) {
      return false;
    }
    _latestSampleAt = sampledAt;
    _revision++;
    return true;
  }

  bool acceptProfilePoll({required int startedAtRevision}) {
    // The public profile RPC has coordinates but no GPS capture timestamp.
    // It can seed tracking, but cannot supersede a timestamped live sample.
    if (startedAtRevision != _revision || _latestSampleAt != null) return false;
    _revision++;
    return true;
  }
}
