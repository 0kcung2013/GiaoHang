/// Helpers for presenting timestamps in Vietnam Standard Time (UTC+7).
///
/// Backend timestamps should continue to be stored as UTC instants. Use
/// [toWallClock] only for calendar calculations and user-facing display.
abstract final class VietnamTime {
  static const utcOffset = Duration(hours: 7);

  /// Converts an instant to a timezone-independent Vietnam wall-clock value.
  ///
  /// The returned [DateTime] intentionally carries local semantics while its
  /// fields always represent UTC+7. Do not serialize it back to the backend.
  static DateTime toWallClock(DateTime value) {
    final shifted = value.toUtc().add(utcOffset);
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
      shifted.microsecond,
    );
  }

  static DateTime now({DateTime? clock}) =>
      toWallClock(clock ?? DateTime.now().toUtc());

  static DateTime dateOnly(DateTime wallClock) =>
      DateTime(wallClock.year, wallClock.month, wallClock.day);
}
